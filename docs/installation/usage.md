---
title: General usage
parent: Installation and usage
has_children: false
nav_order: 40
published: true
---

## {{page.title}}

As [described here](https://midataint.github.io/docs/analysis-flow/)
data analysis in MDI tool suites is divided into two stages called
**pipelines**, which perform high-performance computing on Linux servers,
and **apps**, which support interactive data visualization in R Shiny.

### Methods and help for calling MDI pipelines

Please see the [detailed documentation](https://midataint.github.io/mdi) 
and MDI command help:

```sh
mdi --help
```

for information about the ways you can execute an MDI pipeline on your server. Briefly,
you can run a pipeline action as a program from the command line, e.g.:

```sh
mdi <pipeline> <align> [options] # e.g., mdi svCapture align
```

However, rather than specifying options at the command line, 
we recommend creating a job configuration file and then either calling it directly:

```sh
mdi <pipeline> <job.yml> # e.g., mdi svCapture myJob.yml
```

or, better yet, submitting it to the job scheduler on your HPC cluster:

```sh
mdi submit <job.yml> # e.g., mdi submit myJob.yml
```

### Help for assembling job configuration files

Complete instructions for constructing MDI job files are found here -
there are many additional helpful features.
- <https://midataint.github.io/mdi/docs/job_config_files.html>

The following command will print a template you can use to 
quickly construct a new job file from scratch.

```sh
mdi <pipeline> template --help
mdi <pipeline> template > myJob.yml # e.g., mdi svCapture template
nano myJob.yml
```

Finally, the following commands will give you help screen for a pipeline
or one of its actions to understand how options are organized and what they do:

```sh
mdi <pipeline> --help          # e.g., mdi svCapture --help
mdi <pipeline> <action> --help # e.g., mdi svCapture align --help
```