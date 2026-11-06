"""Public IAccessible facts and messages confined to owned private HWNDs.

No cursor, real keyboard, foreground-window call, input-desktop switch or
SetFocus call is used. Windows translates posted messages in the owned Excel.
"""
import ctypes
from ctypes import wintypes as w
import time
import uuid

import pythoncom
import win32api
import win32com.client
import win32con
import win32gui
import win32process


IID_ACCESSIBLE = pythoncom.MakeIID('{618736E0-3C3D-11CF-810C-00AA00389B71}')


class Guid(ctypes.Structure):
    _fields_ = [('a', w.DWORD), ('b', w.WORD), ('c', w.WORD), ('d', ctypes.c_ubyte * 8)]


class VariantValue(ctypes.Union):
    _fields_ = [('i4', w.LONG), ('pointer', ctypes.c_void_p), ('record', ctypes.c_void_p * 2)]


class Variant(ctypes.Structure):
    _fields_ = [('vt', w.WORD), ('reserved', w.WORD * 3), ('value', VariantValue)]


def method(pointer, index, result, arguments):
    # Standard, documented COM interface vtables only; no Office implementation
    # memory or private interfaces are inspected.
    table = ctypes.cast(pointer, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
    return ctypes.WINFUNCTYPE(result, ctypes.c_void_p, *arguments)(table[index])


def check_hresult(result, operation):
    if result < 0:
        raise OSError(result, operation + ' failed: ' + hex(result & 0xffffffff))


class Accessible:
    """IAccessible's public vtable, since MSForms' IDispatch names omit accLocation."""
    def __init__(self, control):
        unknown = control._oleobj_.QueryInterface(IID_ACCESSIBLE, pythoncom.IID_IUnknown)
        source = pythoncom.CoMarshalInterThreadInterfaceInStream(IID_ACCESSIBLE, unknown)
        source.Seek(0, 0)
        packet = source.Read(65536)
        if not packet or len(packet) == 65536:
            raise ValueError('Invalid public IAccessible marshal packet')
        ole = ctypes.OleDLL('ole32')
        ole.CreateStreamOnHGlobal.argtypes = [w.HGLOBAL, w.BOOL, ctypes.POINTER(ctypes.c_void_p)]
        ole.CreateStreamOnHGlobal.restype = ctypes.HRESULT
        stream = ctypes.c_void_p()
        ole.CreateStreamOnHGlobal(None, True, ctypes.byref(stream))
        try:
            written = w.ULONG()
            check_hresult(method(stream, 4, ctypes.HRESULT, [ctypes.c_void_p, w.ULONG, ctypes.POINTER(w.ULONG)])(
                stream, ctypes.create_string_buffer(packet), len(packet), ctypes.byref(written)), 'IStream.Write')
            if written.value != len(packet):
                raise OSError('Incomplete public COM marshal packet')
            position = ctypes.c_ulonglong()
            check_hresult(method(stream, 5, ctypes.HRESULT, [ctypes.c_longlong, w.DWORD, ctypes.POINTER(ctypes.c_ulonglong)])(
                stream, 0, 0, ctypes.byref(position)), 'IStream.Seek')
            iid = Guid.from_buffer_copy(uuid.UUID(str(IID_ACCESSIBLE)).bytes_le)
            pointer = ctypes.c_void_p()
            ole.CoUnmarshalInterface.argtypes = [ctypes.c_void_p, ctypes.POINTER(Guid), ctypes.POINTER(ctypes.c_void_p)]
            ole.CoUnmarshalInterface.restype = ctypes.HRESULT
            ole.CoUnmarshalInterface(stream, ctypes.byref(iid), ctypes.byref(pointer))
            self.pointer = pointer
        finally:
            method(stream, 2, w.ULONG, [])(stream)

    def close(self):
        if self.pointer:
            method(self.pointer, 2, w.ULONG, [])(self.pointer)
            self.pointer = None

    def child_count(self):
        value = w.LONG()
        check_hresult(method(self.pointer, 8, ctypes.HRESULT, [ctypes.POINTER(w.LONG)])(
            self.pointer, ctypes.byref(value)), 'IAccessible.get_accChildCount')
        return value.value

    def location(self, child_id=0):
        values = [w.LONG() for _ in range(4)]
        child = Variant()
        child.vt = pythoncom.VT_I4
        child.value.i4 = child_id
        check_hresult(method(self.pointer, 22, ctypes.HRESULT, [ctypes.POINTER(w.LONG)] * 4 + [Variant])(
            self.pointer, *(ctypes.byref(v) for v in values), child), 'IAccessible.accLocation')
        return [v.value for v in values]

    def role(self, child_id=0):
        child, result = Variant(), Variant()
        child.vt = pythoncom.VT_I4
        child.value.i4 = child_id
        check_hresult(method(self.pointer, 13, ctypes.HRESULT, [Variant, ctypes.POINTER(Variant)])(
            self.pointer, child, ctypes.byref(result)), 'IAccessible.get_accRole')
        if result.vt != pythoncom.VT_I4:
            raise ValueError('Native accessible role is not a numeric MSAA role')
        return result.value.i4


def accessible(control):
    return Accessible(control)


def property_value(acc, member, child=0):
    if isinstance(acc, Accessible) and member == 'accRole' and child == 0:
        return acc.role()
    return acc._oleobj_.Invoke(acc._oleobj_.GetIDsOfNames(member), 0, pythoncom.DISPATCH_PROPERTYGET, 1, child)


def location(acc):
    if isinstance(acc, Accessible):
        return acc.location()
    return list(acc._oleobj_.InvokeTypes(acc._oleobj_.GetIDsOfNames('accLocation'), 0,
        pythoncom.DISPATCH_METHOD, (pythoncom.VT_VOID, 0),
        ((pythoncom.VT_BYREF | pythoncom.VT_I4, 2),) * 4 + ((pythoncom.VT_VARIANT, 1),),
        None, None, None, None, 0))


def focus_name(form, kinds=None):
    current = form.ActiveControl
    if current is None:
        return ''
    for _ in range(16):
        kind = kinds[str(current.Name)] if kinds else current._oleobj_.GetTypeInfo().GetDocumentation(-1)[0]
        if kind.startswith('I'):
            kind = kind[1:]
        if kind in {'Frame', 'OptionFrame'}:
            child = current.ActiveControl
        elif kind == 'MultiPage':
            child = current.Pages.Item(current.Value).ActiveControl
        else:
            return str(current.Name)
        if child is None:
            return str(current.Name)
        current = child
    raise ValueError('Native focus nesting exceeds the corpus bound')


class GuiInfo(ctypes.Structure):
    _fields_ = [('size', w.DWORD), ('flags', w.DWORD), ('active', w.HWND), ('focus', w.HWND),
                ('capture', w.HWND), ('menu', w.HWND), ('move', w.HWND), ('caret', w.HWND), ('rect', w.RECT)]


def focused_hwnd(root, pid):
    tid, actual_pid = win32process.GetWindowThreadProcessId(root)
    if actual_pid != pid:
        raise ValueError('Native root does not belong to the owned Excel')
    function = ctypes.WinDLL('user32', use_last_error=True).GetGUIThreadInfo
    function.argtypes = [w.DWORD, ctypes.POINTER(GuiInfo)]
    function.restype = w.BOOL
    info = GuiInfo()
    info.size = ctypes.sizeof(info)
    if not function(tid, ctypes.byref(info)):
        raise OSError(ctypes.get_last_error(), 'GetGUIThreadInfo failed')
    if not info.focus or win32process.GetWindowThreadProcessId(info.focus)[1] != pid:
        raise ValueError('Native thread has no owned focus HWND')
    return info.focus


def post_key(root, pid, code):
    target = focused_hwnd(root, pid)
    scan = win32api.MapVirtualKey(code, 0)
    flags = 1 | (scan << 16)
    win32gui.PostMessage(target, win32con.WM_KEYDOWN, code, flags)
    win32gui.PostMessage(target, win32con.WM_KEYUP, code, flags | 0xc0000000)
    time.sleep(.04)
    pythoncom.PumpWaitingMessages()


def click(root, pid, screen_point):
    if win32process.GetWindowThreadProcessId(root)[1] != pid:
        raise ValueError('Native root is not owned')
    # Select the deepest visible owned child containing this point. This is
    # per-window message routing, never a system pointer position or click.
    target = root
    for _ in range(20):
        point = win32gui.ScreenToClient(target, tuple(screen_point))
        child = win32gui.ChildWindowFromPointEx(target, point, win32con.CWP_SKIPINVISIBLE)
        if not child or child == target:
            break
        if win32process.GetWindowThreadProcessId(child)[1] != pid:
            raise ValueError('Native child is not owned')
        target = child
    else:
        raise ValueError('Native child nesting exceeds corpus bound')
    x, y = win32gui.ScreenToClient(target, tuple(screen_point))
    if not -32768 <= x < 32768 or not -32768 <= y < 32768:
        raise ValueError('Invalid native message point')
    packed = (x & 0xffff) | ((y & 0xffff) << 16)
    win32gui.PostMessage(target, win32con.WM_MOUSEMOVE, 0, packed)
    win32gui.PostMessage(target, win32con.WM_LBUTTONDOWN, 1, packed)
    win32gui.PostMessage(target, win32con.WM_LBUTTONUP, 0, packed)
    time.sleep(.04)
    pythoncom.PumpWaitingMessages()
