Status: Open
Target: Foundation
Ask: Land the MS-OFORMS seed/index rows and mirrored DOCX/PDF artifacts in Foundation so OxForms can pin a committed Foundation revision.
Context: OxForms uses MS-OFORMS as its primary clean-room forms specification source for form/control properties, enums, defaults, and persistence facts. The local Foundation worktree has the right files and hashes, but they were not committed when OxForms was bootstrapped.
Evidence: `../Foundation/reference/spec_seeds.csv` row `MS-OFORMS`; `../Foundation/reference/index.csv` rows for `MS-OFORMS`; local artifacts `../Foundation/reference/downloads/officeprotocoldocs-f5hpbjgea6b8gneq.b02.azurefd.net/files/MS-OFORMS/[MS-OFORMS]-250819.docx` (`sha256 7bbbbdc43407524fe2af99c070dfc358cc67404e5224b56d5cdabbc4736c9158`) and `[MS-OFORMS].pdf` (`sha256 37e72c8605244ebd28c2f247f9605d858fb44c194f835867d8b9ecedcb744db4`).
