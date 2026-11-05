# 上传和运行说明

这是新增 S2、S3 以及样本筛选、分组缺失、2011 初始队列随访、观察波次/跨度和分波次结局的补充包。保留原仓库的所有文件。

## 上传

1. 解压本压缩包，得到一个名为 `supplementary_reporting` 的文件夹。
2. 打开原 GitHub 仓库的首页，在仓库根目录选择 **Add file → Upload files**。
3. 拖入整个 `supplementary_reporting` 文件夹，保留它的文件夹层级。它应与原来的 `run.py`、`code`、`reference_results` 并列。
4. 提交说明可以写：`Add supplementary tables S2/S3 and sample reporting code`。
5. 提交后确认 `supplementary_reporting/run.py` 和 `supplementary_reporting/README.md` 可以打开。

不要把补充包里的 `code` 或 `reference_results` 拆出来覆盖原仓库的同名目录。不要上传本地运行后产生的 `runs` 目录、CHARLS 个体数据、城市输入资料或本机配置文件。

## 原仓库首页说明

原首页介绍主要覆盖 Tables 1–11 和 S1，因此建议在该介绍后面增加以下一段，指向新目录。旧入口继续负责原来的表格，新入口负责补充内容：

> Supplementary Tables S2 and S3 and the sample-selection, missingness, follow-up, observation-span, and wave-specific outcome summaries are reproduced by the [supplementary reporting add-on](supplementary_reporting/README.md). Its separate entry point is `python supplementary_reporting/run.py check` for aggregate-only reconstruction or `python supplementary_reporting/run.py full --build-dir "/path/to/completed/build-input-run"` for recalculation from authorized study data. The main `run.py` retains its existing scope.

这一段中的链接应作为 Markdown 写入 README，实际代码如下：

```markdown
Supplementary Tables S2 and S3 and the sample-selection, missingness, follow-up, observation-span, and wave-specific outcome summaries are reproduced by the [supplementary reporting add-on](supplementary_reporting/README.md). Its separate entry point is `python supplementary_reporting/run.py check` for aggregate-only reconstruction or `python supplementary_reporting/run.py full --build-dir "/path/to/completed/build-input-run"` for recalculation from authorized study data. The main `run.py` retains its existing scope.
```

## 运行

在仓库根目录执行：

```bash
python -m pip install -r supplementary_reporting/requirements.txt
python supplementary_reporting/run.py check
```

上面是根据已提供的汇总结果生成表格和正文数字汇总，不是重新估计。

要重新计算，使用原仓库 `build-input` 产生的目录：

```bash
python supplementary_reporting/run.py full --build-dir "/实际路径/runs/build-input_..." --stata "/实际路径/stata-mp"
```

必须保留该上游目录中的 `data/analysis_input.dta`、`data/charls.dta` 和 README 所列的三个 `temp` 文件。仅有最终分析数据，不能还原被前面筛选步骤排除的记录及初始队列的所有后续访谈。

新增输出中的 CSV 是数据和核对结果文件，不意味着论文中又增加了更多表格。论文仍然是 S2、S3 两张新增表，其余数字对应正文说明。
