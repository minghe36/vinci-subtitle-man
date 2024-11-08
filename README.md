# 浩叔的智能字幕生成工具

一个免费开源的达芬奇AI中文字幕生成插件。

做这个插件的起因是市面上没有好用的达芬奇中文视频转录字幕的插件，使用剪映，需要来回切换，非常麻烦，而且剪映生成的字幕错误也很多，现在这个功能还要收费了！就自己做了一个。

![截图](https://file.notion.so/f/f/39985f86-f597-45fc-b3c5-965c6cec3f22/2b7fa505-ea21-48ec-b236-5462cc37deda/iShot_2024-11-08_10.23.03.png?table=block&id=1385b7e2-7560-804d-91e5-d777fd2f507a&spaceId=39985f86-f597-45fc-b3c5-965c6cec3f22&expirationTimestamp=1731124800000&signature=QU3-67gIsxg4iEi3yfyjyCR6uCycgE0xhh9foLLn2e0&downloadName=iShot_2024-11-08_10.23.03.png)


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

### 安装 stable-ts 库


本插件依赖 [stable-ts](https://github.com/jianfch/stable-ts) 库，请确保安装成功，否则无法使用。
stable-ts 是对 open ai 的 whisper 库的优化封装，依赖于 [whisper](https://github.com/openai/whisper).

安装方法：


安装 FFmpeg 依赖库

```
# on Ubuntu or Debian
sudo apt update && sudo apt install ffmpeg

# on Arch Linux
sudo pacman -S ffmpeg

# on MacOS using Homebrew (https://brew.sh/)
brew install ffmpeg

# on Windows using Chocolatey (https://chocolatey.org/)
choco install ffmpeg

# on Windows using Scoop (https://scoop.sh/)
scoop install ffmpeg
```

安装 PyTorch

```
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

安装 stable-ts

```
pip install -U git+https://github.com/jianfch/stable-ts.git@whisperless
```

4. 配置 dify API key

你可以自己在 dify 中配置纠错优化的大模型逻辑，dify 的使用请看我的系列教程：[浩叔的dify+cursor课程](https://space.bilibili.com/1055596703/channel/collectiondetail?sid=3993222)

如果你嫌麻烦，可以先临时使用我的 API key：**app-zZ6K9xI0jC4e3zHa6XiKKcjZ**，我用的是暂时免费的[Grok](https://x.ai/api)模型，优化效果很不错，关键支持长文优化。

（该 API key 不保证长期有效）


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

