# Dockerfile (进一步优化版)
FROM node:18-slim
WORKDIR /app

# 1. [保持不变] 安装最稳定、最不常变化的系统依赖。
RUN apt-get update && apt-get install -y \
    curl \
    libasound2 libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 libcups2 \
    libdbus-1-3 libdrm2 libgbm1 libgtk-3-0 libnspr4 libnss3 libx11-6 \
    libx11-xcb1 libxcb1 libxcomposite1 libxdamage1 libxext6 libxfixes3 \
    libxrandr2 libxss1 libxtst6 xvfb \
    && rm -rf /var/lib/apt/lists/*

# 2. [保持不变] 拷贝 package.json 并安装依赖。
# 只要你的npm包不变化，这一层就会被缓存。
COPY package*.json ./
RUN npm install --production

# 3. 【核心优化】将浏览器下载和解压作为独立的一层。
# 只要CAMOUFOX_URL不变，这一层就会被缓存。这层体积最大，缓存命中至关重要。
ARG CAMOUFOX_URL
RUN apt-get update && apt-get install -y unzip curl && \
    # 1. 下载文件
    curl -sSL ${CAMOUFOX_URL} -o camoufox-linux.zip && \
    # 2. 创建最终的目标目录
    mkdir -p /app/camoufox-linux && \
    \
    # 3. 将文件直接解压到最终的目标目录中
    unzip camoufox-linux.zip -d /app/camoufox-linux && \
    \
    # 4. 删除不再需要的压缩包
    rm camoufox-linux.zip && \
    \
    # 5. 清理 apt 缓存，减小镜像体积
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# [新增] 先将 camoufox 目录复制到镜像中
COPY camoufox-linux/ /app/camoufox-linux/

# 然后再给其中的文件添加执行权限
RUN chmod +x /app/camoufox-linux/camoufox

# 4. 【核心优化】现在，才拷贝你经常变动的代码文件。
# 这一步放在后面，确保你修改代码时，前面所有重量级的层都能利用缓存。
COPY unified-server.js black-browser.js models.json ./

# 5. [保持不变] 创建目录并设置权限。
# 注意：chown应在拷贝文件后进行，确保所有文件权限正确。
RUN mkdir -p ./auth && chown -R node:node /app

# 切换到非 root 用户
USER node

# 暴露服务端口
EXPOSE 7860
EXPOSE 9998

# 设置环境变量
ENV CAMOUFOX_EXECUTABLE_PATH=/app/camoufox-linux/camoufox

# 定义容器启动命令
CMD ["node", "unified-server.js"]
