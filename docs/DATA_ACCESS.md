# Data access and input requirements

## What the repository contains

Complete research programs, a city resampling schedule, aggregate coefficient and uncertainty summaries, saved bootstrap estimates, and verification records. It does not redistribute CHARLS respondent data, respondent identifiers, harmonized survey files, or externally compiled input workbooks. No artificial data are presented as the study data.

## Survey sources

CHARLS data are accessed through the [CHARLS website](https://charls.pku.edu.cn/en/) and its [data portal](https://charls.charlsdata.com/). Obtain the 2011, 2013, 2015, 2018 and 2020 survey releases and applicable PSU/geographic linkage files through the provider's registration and access procedures. The provider's access conditions apply to the survey and any geographic information needed for city linkage.

The construction also uses Harmonized CHARLS C and D releases. The manuscript's input uses the D release for several harmonized variables and the C release for the 2015 education definition. Harmonized survey resources are provided through the [Gateway to Global Aging Data](https://g2aging.org/); obtain the required releases under the provider's access conditions. The source names and version-identifying checksums are listed in `verification/INPUT_MANIFEST.json`.

The full input manifest contains 56 external files, including survey modules, PSU files and the sources below. All 56 were available and checked in the executed validation. They are not included in the public package. A file with the same name is not necessarily the same data release.

## City sources and linkage

| Configurable source | Fields used in construction | Access status in this package |
| --- | --- | --- |
| `citybook` | City/year identifiers, registered population, hospital counts, industrial SO2 emissions; additional construction fields retained | Author-used compiled city database workbook; not distributed |
| `municipal` | GreenCoverageRateBD and RoadSurAreaPerCap, city and year; 2011–2020 including four municipalities | Author-used compiled municipal workbook; not distributed |
| `pm25` | Annual city PM2.5 data for 2011–2020 | External city-level Stata file; not distributed |
| `covidbook` | City case counts used in the upstream construction | External workbook; not distributed; COVID is not a control in this tutorial's main models |

These exact compiled sources are not obtained merely by downloading CHARLS. Their public download locations and redistribution permissions are not established by the materials available for this release. Before presenting full re-estimation as accessible to outside readers, the authors need to provide a legitimate access route for these city inputs, or an authorized route to the linked analysis input. The present package makes that requirement explicit rather than claiming an unrestricted download is available.

The construction code records the city-name harmonization, survey-year matching, policy coding, Social item construction, income adjustment and city merges actually used. It retains upstream steps required to reconstruct the same input even when a resulting field is not used in the tutorial models. The list of policy pilot names in code is a policy-coding rule, not respondent-level information.

## Starting from an authorized linked input

Readers with the same linked input can skip the upstream construction. Supply a Stata `.dta` file with one respondent-wave record and the source variables listed in `MODELS_AND_VARIABLES.md`. The source file may also contain unmatched city-only records; the analysis removes records without valid person/wave identifiers. The public command examples use `analysis_input.dta` as a generic filename; a particular local filename is not required.

The code does not silently impute missing values or replace missing Social responses with zero. The schema and harmonization must match the documented definitions. Under these conditions, the full command reproduces the model estimates and resampling results. Without these data, the `check` command reproduces the interval and adjustment calculations from supplied aggregate outputs.
