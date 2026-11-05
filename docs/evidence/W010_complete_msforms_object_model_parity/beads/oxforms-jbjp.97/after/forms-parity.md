# FORMS PARITY

179 pass; 326 fail, including 292 missing measurements.
Layout tolerance: 1 px. Visible ink tolerance: 2 px. Exact line breaks and ordered behaviour require exact matches.
Missing measurements fail coverage. Colour masks measure visible ink; they do not establish glyph identity or a baseline.
Pixels are a coarse regression guard and do not set priorities.

## LayoutSelection — 100%

| Control | Area / measurement | Result | Native | CalcForms | Maximum difference / tolerance |
|---|---|---|---|---|---|
| (form) | layout / client_size | pass | [440, 280] | [440, 280] | 0 / 1 px |
| (form) | layout / missing_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / extra_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / excel_capture_client_size | pass | [440, 280] | [440, 280] | 0 / 0 px |
| (form) | layout / calcforms_capture_client_size | pass | [440, 280] | [440, 280] | 0 / 0 px |
| Checked | layout / rectangle_edges | pass | [232.0, 16.0, 405.333, 40.0] | [232.0, 16.0, 405.333, 40.0] | 0.0 / 1 px |
| Checked | layout / twips_to_pixel_rounding | pass | [232, 16, 405, 40] | [232, 16, 405, 40] | 0 / 1 px |
| Checked | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Checked | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Checked | text / ink_bounds | pass | [250, 24, 289, 32] | [250, 24, 290, 32] | 1 / 2 px |
| Checked | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Checked | text / caption_0_ink_bounds | pass | [250, 24, 289, 32] | [250, 24, 290, 32] | 1 / 2 px |
| Checked | text / alignment_offsets | pass | [18.0, 8.0] | [18.0, 8.0] | 0.0 / 2 px |
| Checked | spacing / insets | pass | [18.0, 8.0, 116.333, 8.0] | [18.0, 8.0, 115.333, 8.0] | 1.0 / 2 px |
| Checked | colours / text_class | fail | ["dark-text"] | ["shadow-or-disabled"] | 1 / 0 class |
| Checked | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Checked | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Checked | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Checked | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Checked | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Checked | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Checked | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / tab_index | pass | 1 | 1 | 0 / 0 index |
| Checked | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | layout / rectangle_edges | pass | [16.0, 152.0, 189.333, 247.0] | [16.0, 152.0, 189.333, 248.0] | 1.0 / 1 px |
| Choices | layout / twips_to_pixel_rounding | pass | [16, 152, 189, 247] | [16, 152, 189, 248] | 1 / 1 px |
| Choices | layout / control_kind | pass | "ListBox" | "ListBox" | 0 / 0 identity |
| Choices | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Choices | text / ink_bounds | fail | [28, 158, 61, 191] | [27, 157, 64, 191] | 3 / 2 px |
| Choices | text / visible_line_count | pass | 4 | 4 | 0 / 0 lines |
| Choices | text / caption_0_ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / caption_1_ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / caption_2_ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / alignment_offsets | pass | [12.0, 6.0] | [11.0, 5.0] | 1.0 / 2 px |
| Choices | spacing / insets | fail | [12.0, 6.0, 128.333, 56.0] | [11.0, 5.0, 125.333, 57.0] | 3.0 / 2 px |
| Choices | colours / text_class | pass | ["dark-text", "white"] | ["dark-text", "white"] | 0 / 0 class |
| Choices | spacing / list_row_height | pass | [12, 7, 6] | [13, 7, 6] | 1 / 1 px |
| Choices | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Choices | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Choices | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / tab_index | pass | 6 | 6 | 0 / 0 index |
| Choices | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | layout / rectangle_edges | pass | [232.0, 152.0, 405.333, 180.0] | [232.0, 152.0, 405.333, 180.0] | 0.0 / 1 px |
| Dropdown | layout / twips_to_pixel_rounding | pass | [232, 152, 405, 180] | [232, 152, 405, 180] | 0 / 1 px |
| Dropdown | layout / control_kind | pass | "ComboBox" | "ComboBox" | 0 / 0 identity |
| Dropdown | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Dropdown | text / ink_bounds | pass | [244, 159, 264, 167] | [245, 159, 265, 167] | 1 / 2 px |
| Dropdown | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Dropdown | text / caption_0_ink_bounds | pass | [244, 159, 264, 167] | [245, 159, 265, 167] | 1 / 2 px |
| Dropdown | text / alignment_offsets | pass | [12.0, 7.0] | [13.0, 7.0] | 1.0 / 2 px |
| Dropdown | spacing / insets | pass | [12.0, 7.0, 141.333, 13.0] | [13.0, 7.0, 140.333, 13.0] | 1.0 / 2 px |
| Dropdown | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Dropdown | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Dropdown | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Dropdown | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Dropdown | spacing / drop_arrow_bounds | pass | [391, 164, 398, 168] | [390, 164, 397, 168] | 1 / 1 px |
| Dropdown | spacing / drop_button_fill_bounds | fail | [388, 156, 401, 176] | [387, 155, 404, 177] | 3 / 1 px |
| Dropdown | spacing / drop_button_rectangle | pass | [386, 154, 404, 179] | [386.0, 154.0, 404.0, 178.667] | 0.333 / 1 px |
| Dropdown | colours / drop_button_fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Dropdown | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / tab_index | pass | 7 | 7 | 0 / 0 index |
| Dropdown | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | layout / rectangle_edges | pass | [16.0, 56.0, 189.333, 80.0] | [16.0, 56.0, 189.333, 80.0] | 0.0 / 1 px |
| OptionOne | layout / twips_to_pixel_rounding | pass | [16, 56, 189, 80] | [16, 56, 189, 80] | 0 / 1 px |
| OptionOne | layout / control_kind | pass | "OptionButton" | "OptionButton" | 0 / 0 identity |
| OptionOne | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| OptionOne | text / ink_bounds | fail | [34, 64, 86, 72] | [35, 64, 88, 75] | 3 / 2 px |
| OptionOne | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionOne | text / caption_0_ink_bounds | fail | [34, 64, 86, 72] | [35, 64, 88, 75] | 3 / 2 px |
| OptionOne | text / alignment_offsets | pass | [18.0, 8.0] | [19.0, 8.0] | 1.0 / 2 px |
| OptionOne | spacing / insets | fail | [18.0, 8.0, 103.333, 8.0] | [19.0, 8.0, 101.333, 5.0] | 3.0 / 2 px |
| OptionOne | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| OptionOne | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| OptionOne | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| OptionOne | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionOne | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionOne | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionOne | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| OptionOne | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / tab_index | pass | 2 | 2 | 0 / 0 index |
| OptionOne | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | layout / rectangle_edges | pass | [232.0, 56.0, 405.333, 80.0] | [232.0, 56.0, 405.333, 80.0] | 0.0 / 1 px |
| OptionTwo | layout / twips_to_pixel_rounding | pass | [232, 56, 405, 80] | [232, 56, 405, 80] | 0 / 1 px |
| OptionTwo | layout / control_kind | pass | "OptionButton" | "OptionButton" | 0 / 0 identity |
| OptionTwo | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| OptionTwo | text / ink_bounds | pass | [250, 64, 316, 72] | [250, 64, 318, 74] | 2 / 2 px |
| OptionTwo | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionTwo | text / caption_0_ink_bounds | pass | [250, 64, 316, 72] | [250, 64, 318, 74] | 2 / 2 px |
| OptionTwo | text / alignment_offsets | pass | [18.0, 8.0] | [18.0, 8.0] | 0.0 / 2 px |
| OptionTwo | spacing / insets | pass | [18.0, 8.0, 89.333, 8.0] | [18.0, 8.0, 87.333, 6.0] | 2.0 / 2 px |
| OptionTwo | colours / text_class | fail | ["dark-text"] | ["shadow-or-disabled"] | 1 / 0 class |
| OptionTwo | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| OptionTwo | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| OptionTwo | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionTwo | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionTwo | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionTwo | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| OptionTwo | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / tab_index | pass | 3 | 3 | 0 / 0 index |
| OptionTwo | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | layout / rectangle_edges | pass | [16.0, 96.0, 189.333, 128.0] | [16.0, 96.0, 189.333, 128.0] | 0.0 / 1 px |
| ToggleOff | layout / twips_to_pixel_rounding | pass | [16, 96, 189, 128] | [16, 96, 189, 128] | 0 / 1 px |
| ToggleOff | layout / control_kind | pass | "ToggleButton" | "ToggleButton" | 0 / 0 identity |
| ToggleOff | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| ToggleOff | text / ink_bounds | pass | [77, 107, 126, 118] | [79, 108, 127, 119] | 2 / 2 px |
| ToggleOff | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| ToggleOff | text / caption_0_ink_bounds | pass | [77, 107, 126, 118] | [79, 108, 127, 119] | 2 / 2 px |
| ToggleOff | text / alignment_offsets | pass | [61.0, 11.0] | [63.0, 12.0] | 2.0 / 2 px |
| ToggleOff | spacing / insets | pass | [61.0, 11.0, 63.333, 10.0] | [63.0, 12.0, 62.333, 9.0] | 2.0 / 2 px |
| ToggleOff | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| ToggleOff | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| ToggleOff | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| ToggleOff | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOff | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOff | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| ToggleOff | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / tab_index | pass | 4 | 4 | 0 / 0 index |
| ToggleOff | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | layout / rectangle_edges | pass | [232.0, 96.0, 405.333, 128.0] | [232.0, 96.0, 405.333, 128.0] | 0.0 / 1 px |
| ToggleOn | layout / twips_to_pixel_rounding | pass | [232, 96, 405, 128] | [232, 96, 405, 128] | 0 / 1 px |
| ToggleOn | layout / control_kind | pass | "ToggleButton" | "ToggleButton" | 0 / 0 identity |
| ToggleOn | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| ToggleOn | text / ink_bounds | pass | [295, 109, 340, 119] | [295, 108, 342, 119] | 2 / 2 px |
| ToggleOn | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| ToggleOn | text / caption_0_ink_bounds | pass | [295, 109, 340, 119] | [295, 108, 342, 119] | 2 / 2 px |
| ToggleOn | text / alignment_offsets | pass | [63.0, 13.0] | [63.0, 12.0] | 1.0 / 2 px |
| ToggleOn | spacing / insets | pass | [63.0, 13.0, 65.333, 9.0] | [63.0, 12.0, 63.333, 9.0] | 2.0 / 2 px |
| ToggleOn | colours / text_class | fail | ["dark-text"] | ["shadow-or-disabled"] | 1 / 0 class |
| ToggleOn | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| ToggleOn | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| ToggleOn | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOn | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOn | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOn | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOn | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOn | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| ToggleOn | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / tab_index | pass | 5 | 5 | 0 / 0 index |
| ToggleOn | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | layout / rectangle_edges | pass | [16.0, 16.0, 189.333, 40.0] | [16.0, 16.0, 189.333, 40.0] | 0.0 / 1 px |
| Unchecked | layout / twips_to_pixel_rounding | pass | [16, 16, 189, 40] | [16, 16, 189, 40] | 0 / 1 px |
| Unchecked | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Unchecked | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Unchecked | text / ink_bounds | pass | [34, 26, 84, 32] | [35, 24, 86, 32] | 2 / 2 px |
| Unchecked | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Unchecked | text / caption_0_ink_bounds | pass | [34, 26, 84, 32] | [35, 24, 86, 32] | 2 / 2 px |
| Unchecked | text / alignment_offsets | pass | [18.0, 10.0] | [19.0, 8.0] | 2.0 / 2 px |
| Unchecked | spacing / insets | pass | [18.0, 10.0, 105.333, 8.0] | [19.0, 8.0, 103.333, 8.0] | 2.0 / 2 px |
| Unchecked | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Unchecked | spacing / focus_rectangle | fail | [32, 19, 89, 36] | [] | 1 / 1 px |
| Unchecked | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Unchecked | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Unchecked | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Unchecked | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Unchecked | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |

## LayoutSelection — 150%

| Control | Area / measurement | Result | Native | CalcForms | Maximum difference / tolerance |
|---|---|---|---|---|---|
| (form) | layout / client_size | pass | [660, 420] | [660, 420] | 0 / 1 px |
| (form) | layout / missing_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / extra_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / excel_capture_client_size | pass | [660, 420] | [660, 420] | 0 / 0 px |
| (form) | layout / calcforms_capture_client_size | pass | [660, 420] | [660, 420] | 0 / 0 px |
| Checked | layout / rectangle_edges | pass | [348.0, 24.0, 608.0, 60.0] | [348.0, 24.0, 608.0, 60.0] | 0.0 / 1 px |
| Checked | layout / twips_to_pixel_rounding | pass | [348, 24, 608, 60] | [348, 24, 608, 60] | 0 / 1 px |
| Checked | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Checked | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Checked | text / ink_bounds | fail | [373, 35, 433, 48] | [376, 36, 435, 49] | 3 / 2 px |
| Checked | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Checked | text / caption_0_ink_bounds | fail | [373, 35, 433, 48] | [376, 36, 435, 49] | 3 / 2 px |
| Checked | text / alignment_offsets | fail | [25.0, 11.0] | [28.0, 12.0] | 3.0 / 2 px |
| Checked | spacing / insets | fail | [25.0, 11.0, 175.0, 12.0] | [28.0, 12.0, 173.0, 11.0] | 3.0 / 2 px |
| Checked | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Checked | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Checked | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Checked | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Checked | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Checked | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Checked | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Checked | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / tab_index | pass | 1 | 1 | 0 / 0 index |
| Checked | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | layout / rectangle_edges | fail | [24.0, 228.0, 284.0, 370.5] | [24.0, 228.0, 284.0, 372.0] | 1.5 / 1 px |
| Choices | layout / twips_to_pixel_rounding | pass | [24, 228, 284, 371] | [24, 228, 284, 372] | 1 / 1 px |
| Choices | layout / control_kind | pass | "ListBox" | "ListBox" | 0 / 0 identity |
| Choices | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Choices | text / ink_bounds | fail | [43, 235, 98, 287] | [41, 235, 95, 287] | 3 / 2 px |
| Choices | text / visible_line_count | fail | 4 | 3 | 1 / 0 lines |
| Choices | text / caption_0_ink_bounds | fail | unmeasured (0) | [41, 235, 80, 250] | unmeasured (0) / 2 px |
| Choices | text / caption_1_ink_bounds | fail | unmeasured (0) | [42, 255, 72, 267] | unmeasured (0) / 2 px |
| Choices | text / caption_2_ink_bounds | fail | unmeasured (0) | [41, 274, 95, 287] | unmeasured (0) / 2 px |
| Choices | text / alignment_offsets | pass | [19.0, 7.0] | [17.0, 7.0] | 2.0 / 2 px |
| Choices | spacing / insets | fail | [19.0, 7.0, 186.0, 83.5] | [17.0, 7.0, 189.0, 85.0] | 3.0 / 2 px |
| Choices | colours / text_class | pass | ["dark-text", "white"] | ["dark-text", "white"] | 0 / 0 class |
| Choices | spacing / list_row_height | fail | [21, 3, 16] | [20, 19] | 1 / 1 px |
| Choices | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Choices | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Choices | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / tab_index | pass | 6 | 6 | 0 / 0 index |
| Choices | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | layout / rectangle_edges | pass | [348.0, 228.0, 608.0, 270.0] | [348.0, 228.0, 608.0, 270.0] | 0.0 / 1 px |
| Dropdown | layout / twips_to_pixel_rounding | pass | [348, 228, 608, 270] | [348, 228, 608, 270] | 0 / 1 px |
| Dropdown | layout / control_kind | pass | "ComboBox" | "ComboBox" | 0 / 0 identity |
| Dropdown | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Dropdown | text / ink_bounds | pass | [368, 239, 399, 251] | [367, 239, 398, 251] | 1 / 2 px |
| Dropdown | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Dropdown | text / caption_0_ink_bounds | pass | [368, 239, 399, 251] | [367, 239, 398, 251] | 1 / 2 px |
| Dropdown | text / alignment_offsets | pass | [20.0, 11.0] | [19.0, 11.0] | 1.0 / 2 px |
| Dropdown | spacing / insets | pass | [20.0, 11.0, 209.0, 19.0] | [19.0, 11.0, 210.0, 19.0] | 1.0 / 2 px |
| Dropdown | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Dropdown | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Dropdown | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Dropdown | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Dropdown | spacing / drop_arrow_bounds | pass | [586, 246, 597, 252] | [586, 246, 596, 251] | 1 / 1 px |
| Dropdown | spacing / drop_button_fill_bounds | fail | [582, 234, 602, 264] | [581, 233, 604, 266] | 2 / 1 px |
| Dropdown | spacing / drop_button_rectangle | pass | [579, 231, 606, 268] | [579.0, 231.0, 606.0, 268.0] | 0.0 / 1 px |
| Dropdown | colours / drop_button_fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Dropdown | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / tab_index | pass | 7 | 7 | 0 / 0 index |
| Dropdown | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | layout / rectangle_edges | pass | [24.0, 84.0, 284.0, 120.0] | [24.0, 84.0, 284.0, 120.0] | 0.0 / 1 px |
| OptionOne | layout / twips_to_pixel_rounding | pass | [24, 84, 284, 120] | [24, 84, 284, 120] | 0 / 1 px |
| OptionOne | layout / control_kind | pass | "OptionButton" | "OptionButton" | 0 / 0 identity |
| OptionOne | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| OptionOne | text / ink_bounds | fail | [50, 96, 131, 108] | [52, 97, 132, 112] | 4 / 2 px |
| OptionOne | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionOne | text / caption_0_ink_bounds | fail | [50, 96, 131, 108] | [52, 97, 132, 112] | 4 / 2 px |
| OptionOne | text / alignment_offsets | pass | [26.0, 12.0] | [28.0, 13.0] | 2.0 / 2 px |
| OptionOne | spacing / insets | fail | [26.0, 12.0, 153.0, 12.0] | [28.0, 13.0, 152.0, 8.0] | 4.0 / 2 px |
| OptionOne | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| OptionOne | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| OptionOne | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| OptionOne | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionOne | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionOne | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionOne | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| OptionOne | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / tab_index | pass | 2 | 2 | 0 / 0 index |
| OptionOne | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | layout / rectangle_edges | pass | [348.0, 84.0, 608.0, 120.0] | [348.0, 84.0, 608.0, 120.0] | 0.0 / 1 px |
| OptionTwo | layout / twips_to_pixel_rounding | pass | [348, 84, 608, 120] | [348, 84, 608, 120] | 0 / 1 px |
| OptionTwo | layout / control_kind | pass | "OptionButton" | "OptionButton" | 0 / 0 identity |
| OptionTwo | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| OptionTwo | text / ink_bounds | fail | [373, 95, 475, 108] | [376, 96, 477, 112] | 4 / 2 px |
| OptionTwo | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionTwo | text / caption_0_ink_bounds | fail | [373, 95, 475, 108] | [376, 96, 477, 112] | 4 / 2 px |
| OptionTwo | text / alignment_offsets | fail | [25.0, 11.0] | [28.0, 12.0] | 3.0 / 2 px |
| OptionTwo | spacing / insets | fail | [25.0, 11.0, 133.0, 12.0] | [28.0, 12.0, 131.0, 8.0] | 4.0 / 2 px |
| OptionTwo | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| OptionTwo | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| OptionTwo | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| OptionTwo | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionTwo | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionTwo | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionTwo | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| OptionTwo | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / tab_index | pass | 3 | 3 | 0 / 0 index |
| OptionTwo | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | layout / rectangle_edges | pass | [24.0, 144.0, 284.0, 192.0] | [24.0, 144.0, 284.0, 192.0] | 0.0 / 1 px |
| ToggleOff | layout / twips_to_pixel_rounding | pass | [24, 144, 284, 192] | [24, 144, 284, 192] | 0 / 1 px |
| ToggleOff | layout / control_kind | pass | "ToggleButton" | "ToggleButton" | 0 / 0 identity |
| ToggleOff | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| ToggleOff | text / ink_bounds | pass | [117, 161, 190, 177] | [118, 162, 191, 178] | 1 / 2 px |
| ToggleOff | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| ToggleOff | text / caption_0_ink_bounds | pass | [117, 161, 190, 177] | [118, 162, 191, 178] | 1 / 2 px |
| ToggleOff | text / alignment_offsets | pass | [93.0, 17.0] | [94.0, 18.0] | 1.0 / 2 px |
| ToggleOff | spacing / insets | pass | [93.0, 17.0, 94.0, 15.0] | [94.0, 18.0, 93.0, 14.0] | 1.0 / 2 px |
| ToggleOff | colours / text_class | fail | ["chromatic"] | ["dark-text"] | 1 / 0 class |
| ToggleOff | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| ToggleOff | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| ToggleOff | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOff | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOff | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| ToggleOff | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / tab_index | pass | 4 | 4 | 0 / 0 index |
| ToggleOff | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | layout / rectangle_edges | pass | [348.0, 144.0, 608.0, 192.0] | [348.0, 144.0, 608.0, 192.0] | 0.0 / 1 px |
| ToggleOn | layout / twips_to_pixel_rounding | pass | [348, 144, 608, 192] | [348, 144, 608, 192] | 0 / 1 px |
| ToggleOn | layout / control_kind | pass | "ToggleButton" | "ToggleButton" | 0 / 0 identity |
| ToggleOn | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| ToggleOn | text / ink_bounds | pass | [442, 162, 512, 178] | [443, 162, 512, 178] | 1 / 2 px |
| ToggleOn | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| ToggleOn | text / caption_0_ink_bounds | pass | [442, 162, 512, 178] | [443, 162, 512, 178] | 1 / 2 px |
| ToggleOn | text / alignment_offsets | pass | [94.0, 18.0] | [95.0, 18.0] | 1.0 / 2 px |
| ToggleOn | spacing / insets | pass | [94.0, 18.0, 96.0, 14.0] | [95.0, 18.0, 96.0, 14.0] | 1.0 / 2 px |
| ToggleOn | colours / text_class | fail | ["chromatic"] | ["dark-text"] | 1 / 0 class |
| ToggleOn | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| ToggleOn | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| ToggleOn | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOn | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOn | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOn | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOn | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOn | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| ToggleOn | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / tab_index | pass | 5 | 5 | 0 / 0 index |
| ToggleOn | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | layout / rectangle_edges | pass | [24.0, 24.0, 284.0, 60.0] | [24.0, 24.0, 284.0, 60.0] | 0.0 / 1 px |
| Unchecked | layout / twips_to_pixel_rounding | pass | [24, 24, 284, 60] | [24, 24, 284, 60] | 0 / 1 px |
| Unchecked | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Unchecked | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Unchecked | text / ink_bounds | fail | [46, 35, 131, 54] | [52, 36, 129, 49] | 6 / 2 px |
| Unchecked | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Unchecked | text / caption_0_ink_bounds | fail | [46, 35, 131, 54] | [52, 36, 129, 49] | 6 / 2 px |
| Unchecked | text / alignment_offsets | fail | [22.0, 11.0] | [28.0, 12.0] | 6.0 / 2 px |
| Unchecked | spacing / insets | fail | [22.0, 11.0, 153.0, 6.0] | [28.0, 12.0, 155.0, 11.0] | 6.0 / 2 px |
| Unchecked | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Unchecked | spacing / focus_rectangle | fail | [46, 29, 131, 42] | [] | 1 / 1 px |
| Unchecked | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Unchecked | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Unchecked | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Unchecked | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Unchecked | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
