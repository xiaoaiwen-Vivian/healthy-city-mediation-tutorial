# Third-party software notices

The research workflow is supplied separately from its third-party Stata dependencies. Third-party code retains its original author and copyright notices and is not relabeled as the manuscript authors' work.

| Component | Tested version/source | Attribution and terms |
| --- | --- | --- |
| reghdfe | 6.13.1, 10 January 2026 | Sergio Correia; MIT license; see vendor license file |
| ftools and ms_* helpers | 2.50.0, 9 January 2026 | Sergio Correia; MIT license; see vendor license file |
| sreshape | Author's 2015 program supplied with the source workflow | Kenneth L. Simons; original notices retained in ado/help files |
| boottest | 4.5.5; official source commit 13182315c896438ced53d84a9b9be8f8a854a0e6 | David Roodman; GNU GPL v3 or later, per source header |

boottest source: https://github.com/droodman/boottest/tree/13182315c896438ced53d84a9b9be8f8a854a0e6 . Its bundled library was compiled with Stata 18; the statistical source was not modified. Other dependencies were copied from the tested installations with their sources and help files.

This packaging step does not choose an additional reuse license for the authors' original research code, transfer rights in the underlying datasets, or include a Stata license. The authors can select an appropriate license for their own code when preparing the public release; third-party terms remain applicable.
