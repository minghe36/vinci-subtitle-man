## hao-one达芬奇字幕插件说明

开源的版本安装比较复杂，受限本机性能，转录慢，纠错容易失败。重新做了一个新的高可用、安装简单的的达芬奇字幕插件与语言合成插件，目前已经更新到v6，支持 mac 与 windows。

### 下载地址：[https://www.hao-one.com](https://www.hao-one.com)

### hao-one达芬奇字幕插件功能介绍：

- 体验好，全流程在剪辑软件中，无需多个软件切换
- 强大的 AI 纠错/润色/文稿匹配，可以明显帮你减少人工修正量
- 字幕生成准确度与速度优于剪映与达芬奇本地转录
- 转录支持多个语言
- 支持翻译字幕、中英双语字幕
- 市面上最便宜的在线转录服务
- 支持批量修改字幕

### hao-one达芬奇语音合成插件功能介绍：

- 体验好，全流程在剪辑软件中，无需多个软件切换
- 基于微软语音合成，常用国家250+种音色
- 带有批量加停顿、过长分句、发音优化、快速生成精准字幕等功能
- 一次性可合成最多 5000 千汉字


## 开源版本介绍

一个免费开源的达芬奇AI中文字幕生成插件。

做这个插件的起因是市面上没有好用的达芬奇中文视频转录字幕的插件，使用剪映，需要来回切换，非常麻烦，而且剪映生成的字幕错误也很多，现在这个功能还要收费了！就自己做了一个。

[dify 工作流文件](https://res.cloudinary.com/dpzscy2ao/raw/upload/v1731805929/%E8%BE%BE%E8%8A%AC%E5%A5%87%E5%AD%97%E5%B9%95%E7%94%9F%E6%88%90%E6%8F%92%E4%BB%B60.2_zu4upj.yml)

[插件安装与自定义纠错工作流视频教程](https://www.bilibili.com/video/BV1HwmoYREoQ/?spm_id_from=333.999.0.0&vd_source=50c41c1bed77ff65f5947e5b52ba3e85)

[插件使用教程视频](https://www.bilibili.com/video/BV1R1DqYeEdL/?spm_id_from=333.999.0.0&vd_source=50c41c1bed77ff65f5947e5b52ba3e85)

![截图](https://res.cloudinary.com/dpzscy2ao/image/upload/v1731805348/iShot_2024-11-17_09.02.17_stnhd5.png)

[达芬奇插件的视频开发教程](https://www.yuque.com/xiewenhao-9gxwj/zvkb97/lwxp5u4bwm4nv8h1)

## 功能特点

- 本地运行，免费的
- 效率高，全程点一点，自动完成，无需在多个软件切换
- 支持使用 dify 进行字幕优化，可以自定义纠错规则，支持基于文稿修正字幕
- 支持直接编辑和更新字幕内容

## 安装说明

### 在 github 中下载插件代码

### 将插件文件夹复制到达芬奇插件目录下，目录路径：
   - mac：/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts
   - win：C:\Users\[用户名]\AppData\Roaming\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts

### 安装方法 1：使用一键安装脚本安装插件

为了更方便大家安装，特意写了一个一键安装的脚本，你可以插件目录中找到 install.py 文件。
确保本机安装了 python3 与 Homebrew ，即可以在终端中执行python与 brew 命令。 
打开命令行终端，找到插件目录下的 install.py 安装脚本，执行安装：

```bash
python install.py
```
(install.py 路径记得换成你自己的路径)


如果安装顺利的话，执行 stable-ts --version命令能够成功，说明就安装成功了。

brew 安装 ffmpeg 时可能会遇到网络问题，安装失败的，可以试下第二种安装方法。

### 安装方法 2：使用Anaconda安装插件

Anaconda 允许用户创建和管理多个独立的 Python 环境，集成了强大的包管理工具 conda，可以轻松安装、更新和卸载各种软件包，并自动处理依赖关系。这简化了环境配置和依赖管理的过程。

访问[Anaconda官网](https://www.anaconda.com/download)下载安装包，可以选择跳过注册，直接下载。

安装成功后，在终端中运行 conda 命令试试看。

没有问题，我们就使用 conda 来安装 stable-ts ：

创建并激活新的 python 环境

```bash
conda create -n stable-ts python=3.9
conda activate stable-ts
```
安装FFmpeg

```bash
conda install ffmpeg
```

安装PyTorch 

```bash
conda install pytorch torchvision torchaudio -c pytorch
```

安装stable-ts

```bash  
pip install -U git+https://github.com/jianfch/stable-ts.git
```

安装成功后，就可以执行 stable-ts --version 试试。

### 配置 dify API key

你可以自己在 dify 中配置纠错优化的大模型逻辑，dify 的使用请看我的系列教程：[浩叔的dify+cursor课程](https://space.bilibili.com/1055596703/channel/collectiondetail?sid=3993222)

如果你嫌麻烦，可以先临时使用我的 API key：**app-zZ6K9xI0jC4e3zHa6XiKKcjZ**，我用的是暂时免费的[Grok](https://x.ai/api)模型，优化效果很不错，关键支持长文优化。

（该 API key 不保证长期有效，目前是有每个月 25美元的免费额度）


## 使用步骤

### 第一步：生成字幕初稿

1. 选择合适的转录模型：
   - base：基础模型，速度最快，准确度一般
   - small：小型模型，推荐使用，速度和准确度均衡
   - medium：中型模型，准确度较高，速度较慢
   - large：大型模型，准确度最高，速度最慢
 推荐使用 small 来生成，medium、large 虽然效果更好，但转录速度很慢，通过 small 生成初稿，再通过 dify 使用大模型二次优化字幕效果更好
2. 选择视频语言：
   - 支持中文、英语、日语、韩语、德语、法语
   - 选择正确的语言可以提高识别准确度

3. 点击"生成字幕初稿"按钮：
   - 插件会自动渲染时间线在插件 temp 目录下生成.wav 音频文件
   - 使用 stable-ts 进行语音识别
   - 生成 SRT 格式字幕文件

### 第二步：优化字幕（可选）

1. 填写必要信息：
   - dify key（必填）：填写您的 dify API 密钥
   - 文稿链接（选填）：可以提供参考文稿链接
   - 字幕优化规则（选填）：可以设置特定的优化规则

2. 点击"使用dify优化字幕"按钮：
   - 调用 dify API 进行字幕优化
   - 支持根据文稿和规则进行调整
   - 优化结果会自动更新到字幕框中

基于文稿优化，确保文稿链接是公开可访问的。

### 第三步：插入字幕

1. 编辑字幕内容（如需要）：
   - 在右侧字幕框中直接编辑
   - 点击"更新字幕"保存修改

2. 点击"将字幕插入到时间线"按钮：
   - 自动将字幕导入到媒体池
   - 自动添加到当前时间线
   - 完成字幕插入

