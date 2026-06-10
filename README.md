# jenkins-practice — 通用 Jenkins 平台

Jenkins Master + Registry 的容器化部署，对标公司 `jenkins2k8s` 平台层。

## 三层架构

```
practice/          = 平台层：Jenkins Master + Registry（对标 jenkins2k8s）
config/<project>/  = 编排层：Jenkinsfile + 脚本（对标 ci2k8s）
<project repo>     = 业务层：纯业务代码
```

| 公司 | 本地 |
|------|------|
| `jenkins2k8s`（Helm + JCasC） | `practice/`（Docker Compose + JCasC） |
| `ops/ci2k8s`（Git Monorepo） | `config/<project>/` |
| Jenkins UI 建 Job 壳 | `register-jobs.sh` 注册 Job 壳 |
| git push Jenkinsfile 即生效 | 同上 |

## 首次部署

```bash
cd practice

# 1. 启动平台
./init.sh

# 2. 注册 Job（一次性，之后改 Jenkinsfile push 即生效）
./register-jobs.sh
```

## 日常使用

```bash
# 启动 / 重启
docker compose up -d

# 停止
./stop.sh

# 改了 Jenkinsfile / scripts
#   → git push 即可，下次构建自动拉最新

# 新增项目
#   → 创建 config/<project>/ 目录，参考 config/README.md
#   → ./register-jobs.sh <project>
```

## 服务地址

| 服务 | 地址 |
|------|------|
| Jenkins | http://localhost:8080/ （admin / admin123） |
| Registry | http://localhost:5050/v2/_catalog |

## 什么时候需要重跑？

| 场景 | 操作 |
|------|------|
| 改了 Jenkinsfile / scripts | **不用跑任何脚本**，push 即生效 |
| 新增项目 Job | `./register-jobs.sh <project>` |
| 改了 Job XML（参数、SCM 路径） | `./register-jobs.sh <project>` |
| 日常重启 | `docker compose up -d` |
| 删了 volume / 换机器 | `./init.sh && ./register-jobs.sh` |

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
| `init.sh` | 平台初始化（启动 Docker + 配置 proxy） |
| `register-jobs.sh` | Job 注册（扫描 config/ 下所有项目） |
| `cleanup.sh` | 镜像清理（宿主机残留 + Registry 旧 tag） |
| `stop.sh` | 关闭脚本 |
| `plugins.txt` | Jenkins 插件清单 |
