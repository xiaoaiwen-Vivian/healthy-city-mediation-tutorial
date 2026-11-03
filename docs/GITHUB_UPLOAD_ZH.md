# GitHub 上传和论文引用说明

这个压缩包是供作者审核的完整代码包，目前尚未替你上传。建议先审核 README 中的数据访问说明，再发布一个与返修稿对应的固定版本。

## 一、创建仓库

登录 GitHub，点击右上角“＋”→“New repository”。仓库名可以使用 `healthy-city-mediation-tutorial`。选择 Public，使编辑和读者无需额外授权即可查看代码。这个包已经包含 README 和 .gitignore，不需要让 GitHub 再生成同名文件。创建仓库。[GitHub 官方建库说明](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository)

## 二、上传解压后的内容

解压收到的 ZIP，打开 `HealthyCity_Mediation_Reproducibility` 文件夹。仓库根目录应直接出现 `README.md`、`run.py`、`requirements.txt`、`code/` 等，而不是再嵌套一层同名文件夹。

进入仓库，选择 **Add file → Upload files**，拖入文件或文件夹并提交。浏览器一次最多上传 100 个文件、单文件最多 25 MiB。这个更新包有191个文件，每个文件均低于该大小限制。可分三批：第一批根目录文件及 `code/`、`docs/`、`data/`、`tests/`；第二批 `reference_results/` 和 `verification/`；第三批 `vendor/`。保留原目录结构，也要包含根目录的 `config.upstream.example.do` 和隐藏文件 `.gitignore`。[GitHub 官方上传说明](https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository)

上传的是这个交付 ZIP 解压后的内容。不要上传本机测试产生的 `runs/`、原始调查数据、城市输入工作簿或私人配置文件。这些内容没有放入交付 ZIP；.gitignore 也设置了相应排除规则。浏览器上传不会替你遵守所有本地 Git 规则，因此直接使用交付包最清楚。

## 三、发布固定版本

在仓库右侧进入 **Releases → Draft a new release**，新建标签 `v1.0.0`，标题可写 `Reproducibility materials for the revised manuscript`。描述中说明：采用候选指标内部共同样本，含 Stata/Python 程序、完整 bootstrap 输出、共享城市抽样矩阵和 README。把审核后的整个 ZIP 作为附件上传，然后点击 **Publish release**。[GitHub 官方 Release 说明](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)

论文优先引用这个固定 Release 的实际链接；以后有修改，用新标签发布，保留旧版本。GitHub 自动生成的 Source code ZIP 也可下载。不要在论文中只写“代码在 GitHub”，应给出准确 URL 和版本。

## 四、可选：为代码申请归档 DOI

可把公开 GitHub 仓库连接到 Zenodo，在发布 Release 时归档并生成代码版本 DOI。论文已有的 Research Square DOI 指向预印本，不能替代代码包 DOI。[GitHub 官方归档引用说明](https://docs.github.com/en/repositories/archiving-a-github-repository/referencing-and-citing-content)

## 五、论文中的材料位置说明

实际上传并检查无登录访问和下载后，可采用下面这段，并把方括号替换成真实 Release URL 或代码 DOI。当前占位地址不能直接留在投稿稿件中。

> The Stata and Python programs, shared city-bootstrap resampling schedule, saved bootstrap estimates, and aggregate reference results are available at [RELEASE URL OR ARCHIVAL DOI]. The repository README documents software requirements, data access conditions, the execution sequence, and expected outputs. The analyses use a common sample within each candidate pathway. Individual-level survey data are not redistributed; the repository provides instructions for obtaining the required survey and linked city inputs.

最后一句只有在城市输入的访问途径补充完整后才足以回应外部读者的完整复现需求。目前 `DATA_ACCESS.md` 已如实列明所需输入，但部分城市工作簿的公开获取位置仍需作者确认。

## 六、上传后核对

用未登录窗口打开实际 Release 链接，确认 README、程序及 ZIP 可下载。重新下载并解压，在有 Python 依赖的环境中运行 `python run.py check`，确认出现 `REPRODUCTION_CHECK_PASSED`。将最终链接填入论文、返修信和期刊补充材料说明。代码能运行、数据是否可获得和因果结论是否成立是不同的问题，应分别说明。
