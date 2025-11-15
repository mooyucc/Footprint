# GitHub 自动上传指南

## 📦 已创建的文件

- `init_git.sh` - 初始化Git仓库脚本（首次使用）
- `upload.sh` - 自动上传代码脚本（日常使用）

## 🚀 快速开始

### 第一步：初始化仓库（仅首次使用）

```bash
./init_git.sh
```

这个脚本会：
- 初始化Git仓库
- 配置远程仓库地址（https://github.com/mooyucc/Footprint.git）
- 创建`.gitignore`文件（如果不存在）

### 第二步：上传代码

```bash
# 使用默认提交信息（包含时间戳）
./upload.sh

# 或者指定自定义提交信息
./upload.sh "添加新功能"
./upload.sh "修复bug"
./upload.sh "更新文档"
```

## 📝 详细说明

### 脚本功能

#### init_git.sh
- ✅ 自动检测并初始化Git仓库
- ✅ 配置GitHub远程仓库
- ✅ 创建标准的iOS/Swift项目`.gitignore`文件
- ✅ 显示当前仓库状态

#### upload.sh
- ✅ 自动添加所有更改（`git add .`）
- ✅ 自动提交（`git commit`）
- ✅ 自动推送到GitHub（`git push`）
- ✅ 智能处理首次推送
- ✅ 支持自定义提交信息
- ✅ 错误提示和建议

### 使用示例

```bash
# 1. 首次使用 - 初始化
./init_git.sh

# 2. 日常更新代码
./upload.sh "完成目的地列表功能"

# 3. 快速上传（使用默认信息）
./upload.sh

# 4. 修复bug后上传
./upload.sh "修复地图显示问题"

# 5. 更新文档
./upload.sh "更新README文档"
```

## ⚙️ GitHub认证配置

首次推送到GitHub时，你需要配置认证。有两种方式：

### 方式一：使用Personal Access Token（推荐）

1. 访问 GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. 点击 "Generate new token (classic)"
3. 勾选 `repo` 权限
4. 生成并保存token
5. 首次推送时，使用token作为密码

### 方式二：使用SSH密钥

1. 生成SSH密钥：
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

2. 添加到GitHub：
```bash
cat ~/.ssh/id_ed25519.pub
```
复制输出，添加到 GitHub Settings → SSH and GPG keys

3. 修改远程仓库地址：
```bash
git remote set-url origin git@github.com:mooyucc/Footprint.git
```

## 🔍 常见问题

### Q1: 推送失败，提示认证错误
**解决方案**：配置Personal Access Token或SSH密钥（见上方）

### Q2: 推送失败，提示远程有更新
**解决方案**：
```bash
git pull origin main --rebase
./upload.sh "合并远程更改"
```

### Q3: 想要撤销上次提交
**解决方案**：
```bash
# 撤销提交但保留更改
git reset --soft HEAD~1

# 撤销提交并丢弃更改（危险操作！）
git reset --hard HEAD~1
```

### Q4: 想要查看提交历史
**解决方案**：
```bash
git log --oneline
```

### Q5: 想要忽略某些文件
**解决方案**：编辑`.gitignore`文件，添加需要忽略的文件或文件夹

## 📚 常用Git命令

```bash
# 查看状态
git status

# 查看更改
git diff

# 查看提交历史
git log

# 查看远程仓库
git remote -v

# 拉取最新代码
git pull

# 查看分支
git branch

# 切换分支
git checkout <branch-name>

# 创建并切换到新分支
git checkout -b <new-branch-name>
```

## 🎯 最佳实践

1. **频繁提交**：每完成一个功能或修复一个问题就提交
2. **清晰的提交信息**：描述你做了什么更改
3. **定期推送**：不要积累太多本地提交
4. **先拉取再推送**：多人协作时先`git pull`再`git push`

## 📞 需要帮助？

如果遇到问题：
1. 查看脚本输出的错误信息
2. 查阅本指南的"常见问题"部分
3. 查看GitHub仓库：https://github.com/mooyucc/Footprint

---

**提示**：这些脚本已经配置好了所有必要的设置，你只需要按照步骤操作即可！🎉

