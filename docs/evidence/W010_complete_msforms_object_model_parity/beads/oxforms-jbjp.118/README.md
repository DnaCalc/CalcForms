# Native first-Show and IntegralHeight observations

The .112 capture first reads Height=71.25 after setting 72 before first Show;
subsequent setter snapshots read 72. The new inventory capture reads 72 before
and after Show, with Tahoma 8.25 and IntegralHeight=True at both scales.
Explicit flag probes also retain native TopIndex=16 for True and 15 for False.
These observations are retained with exact source hashes. They do not establish
a uniform layout/property timing rule, and full public Height rounding / IntegralHeight setter behavior remains open.
The bounded first-Show effective viewport is corrected in .121; earlier native
property timing observations and their limits remain unchanged.
