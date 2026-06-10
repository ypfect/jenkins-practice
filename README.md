# jenkins-practice — 通用 Jenkins 环境

Jenkins Master + Registry 的容器化部署。与项目配置目录（如 `../config/<project>/`）配合使用。

## 定位

```
practice/          = 平台层：通用 Jenkins + Registry 环境
config/<project>/  = 编排层：项目专属的 Jenkinsfile、Job XML、脚本
<project repo>     = 业务层：纯业务代码
```

## 首次部署

```bash
cd practice
./init.sh
```

可通过 `JOBS_DIR` 指定要注册的 Job 目录（默认 `./jobs`）：

```bash
JOBS_DIR=../config/deepModel/jobs ./init.sh
```

`init.sh` 做什么：
1. `docker compose up -d --build`（构建 Jenkins 镜像 + 启动 Registry）
2. 等待 Jenkins 就绪
3. 配置容器内 git proxy
4. 扫描 `JOBS_DIR` 下所有 `*.xml`，注册为 Jenkins Job

## 日常使用

```bash
# 启动
docker compose up -d

# 停止
./stop.sh
```

所有配置（Job、git proxy、构建历史）在 `jenkins_home` volume 里，重启不丢。

## 服务地址

| 服务 | 地址 |
|------|------|
| Jenkins | http://localhost:8080/ （admin / admin123） |
| Registry | http://localhost:5050/v2/_catalog |

## 什么时候需要重跑 init.sh？

| 场景 | 需要 |
|------|------|
| 删了 `jenkins_home` volume | 是 |
| 换了机器 / 重装 Docker | 是 |
| 改了 Job XML 配置 | 是（或 Jenkins UI 直接改） |
| 新增项目 Job | 是（指定对应 JOBS_DIR） |
| 日常重启 | **不需要，`docker compose up -d` 即可** |

## 代理（Clash 7890）

容器内 Git/Maven 走 Mac 代理 `http://host.docker.internal:7890`（需 Clash **Allow LAN** 开启）。

## 本地 Registry

- 查看已推送的镜像：`curl http://localhost:5050/v2/_catalog`
- 查看某镜像 tag：`curl http://localhost:5050/v2/<name>/tags/list`
- 数据持久化在 Docker volume `registry_data`

### insecure-registries（Colima 用户需配）

```bash
colima stop
colima start --edit
# 找到 docker: {} 改为：
#   docker:
#     insecure-registries:
#       - localhost:5050
```

## 文件清单

| 文件 | 用途 |
|------|------|
| `docker-compose.yml` | Jenkins Master + Registry 容器编排 |
| `Dockerfile` | 自定义 Jenkins 镜像（插件 + docker CLI） |
| `Dockerfile.app` | 通用 Java 应用镜像模板 |
| `casc/jenkins.yaml` | JCasC：用户、执行器数 |
| `init.sh` | 初始化脚本（启动 + 注册 Job） |
| `stop.sh` | 关闭脚本 |
| `plugins.txt` | Jenkins 插件清单 |
