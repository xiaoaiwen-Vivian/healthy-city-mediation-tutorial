# Update prepared on 2026-11-03

- Align exports with the revised manuscript: Table 8 contains individual component-path BH values, Tables 9 and 10 contain descriptive city and individual bootstrap calculations, and S1 contains all 13 unadjusted WCB coefficient tests.
- Read tracked Word revisions correctly and identify tables by captions. Deleted old tables are excluded. The numeric checker covers 288 displayed entries and can run through `run.py --manuscript`.
- Separate five hypothesis-testing families from two descriptive calculation groups in outputs and documentation. The 42 numerical BH calculations are unchanged.
- Include `config.upstream.example.do` in the distributable ZIP; it was inadvertently absent from the earlier ZIP.
- Preserve model specifications, candidate-specific common samples, data transformations, seeds, all six candidates, 2,000 pairs-bootstrap replications, 9,999 wild-bootstrap replications and the original frozen reference results.

The executed reproduction report accompanies this update. The release does not include participant records or externally controlled input workbooks, and has not been uploaded to a public repository by this process.
