# ==========================================================
# Dockerfile
# ==========================================================
# Title       : Semantic_suma_tensorRT8.x Dockerfile.
# Description : A Dockerfile suitable for TensorRT 8.x versions.
# Author      : [Jialu Li]
# Created on  : [2024-12-16]
# Updated on  : [2024-12-16]
# ==========================================================

# Use the specified version of the TensorRT image as the base image
# 使用指定版本的 TensorRT 镜像作为基础镜像

# CUDA 10.1.243, cuDNN 7.6.2, TensorRT 5.1.5
# FROM nvcr.io/nvidia/tensorrt:19.08-py3

# CUDA 11.0、cuDNN 8.0.3 和 TensorRT 7.1.3
# FROM nvcr.io/nvidia/tensorrt:20.08-py3 

# CUDA 11.3、cuDNN 8.2.1 和 TensorRT 8.2.1
# FROM nvcr.io/nvidia/tensorrt:21.11-py3 

# CUDA 11.8、cuDNN 8.6.0 和 TensorRT 8.5.2
FROM nvcr.io/nvidia/tensorrt:22.12-py3

# Set non-interactive frontend to avoid prompts during build
# 设置非交互式前端，避免在构建过程中出现交互提示
ARG DEBIAN_FRONTEND=noninteractive

# Configure NVIDIA environment variables
# 配置 NVIDIA 环境变量
ENV NVIDIA_VISIBLE_DEVICES \
    ${NVIDIA_VISIBLE_DEVICES:-all}
ENV NVIDIA_DRIVER_CAPABILITIES \
    ${NVIDIA_DRIVER_CAPABILITIES:+$NVIDIA_DRIVER_CAPABILITIES,}graphics

# Update and install necessary dependencies 
# 更新并安装必要的依赖项
RUN apt-get -y update &&\
    apt-get -y upgrade &&\
    apt-get install -y apt-utils build-essential cmake curl libgtest-dev libeigen3-dev libboost-all-dev qtbase5-dev libglew-dev qt5-default git libyaml-cpp-dev libopencv-dev vim

# Install GTSAM library
# 添加 GTSAM 的 PPA 源并安装相关库
RUN apt-get -y install software-properties-common &&\
    add-apt-repository ppa:borglab/gtsam-release-4.0 &&\
    apt-get -y update &&\
    apt-get install -y libgtsam-dev libgtsam-unstable-dev

# ROS Noetic        
RUN apt-get install -y lsb-release &&\
    sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list' &&\
    curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add - &&\
    apt-get update -y &&\
    apt-get install -y ros-noetic-desktop-full
RUN apt-get install -y python3-catkin-pkg python3-wstool python3-rosdep ninja-build stow python3-rosinstall python3-rosinstall-generator

# Install ROS dependencies and fix permissions
# 初始化 rosdep 并修复权限
RUN rosdep init &&\
    sudo rosdep fix-permissions &&\
    rosdep update

# Install Python 3 and pip
# 安装 Python 包
RUN python3 -m pip install --upgrade pip
RUN pip install catkin_tools catkin_tools_fetch empy trollius numpy rosinstall_generator

# Create workspace directory and clone RangeNetLib and Suma++ repositories
# 创建工作空间目录并克隆 RangeNetLib 和 Suma++ 的代码库
RUN mkdir -p /catkin_ws/src
WORKDIR /catkin_ws/src
RUN git clone http://github.com/ros/catkin.git &&\
    # add new rangenet_lib for tersorRT8XX
    # 添加新版本rangenet_lib
    git clone https://github.com/vincenzo0603/rangenet_lib_forTensorRT8XX
# note old version rangenet_lib
# 注释老版本rangenet_lib
# git clone https://github.com/PRBonn/rangenet_lib.git
# RUN sed -i 's/builder->setFp16Mode(true)/builder->setFp16Mode(false)/g' /catkin_ws/src/rangenet_lib/src/netTensorRT.cpp
# RUN sed -i 's/builder->setFp16Mode(true)/builder->setFp16Mode(false)/g' /catkin_ws/src/rangenet_lib/src/netTensorRT.cpp

# Build the rangenet_lib package
# 构建 rangenet_lib 包
RUN cd ../ && catkin init &&\
    catkin build rangenet_lib

# Check for OpenCV4 and create a symbolic link if it exists
# 检查是否存在 OpenCV4，如果存在则创建软链接
RUN pkg-config --cflags opencv4 &&\
    ln -s /usr/include/opencv4/opencv2 /usr/include/opencv2

# Clone the semantic_suma repository and make necessary modifications
# 克隆 semantic_suma 仓库并进行必要的修改
RUN git clone http://github.com/PRBonn/semantic_suma.git &&\
    # change /catkin_ws/src/semantic_suma/src/rv/Laserscan.h:17:10
    sed -i 's|#include <opencv2/core/core.hpp>|#include <opencv2/core.hpp>|g' /catkin_ws/src/semantic_suma/src/rv/Laserscan.h &&\
    # check the change success or not
    sed -n '17p' /catkin_ws/src/semantic_suma/src/rv/Laserscan.h &&\
    sed -i 's/find_package(Boost REQUIRED COMPONENTS filesystem system)/find_package(Boost 1.65.1 REQUIRED COMPONENTS filesystem system serialization thread date_time regex timer chrono)/g' /catkin_ws/src/semantic_suma/CMakeLists.txt &&\
    catkin init &&\
    catkin deps fetch &&\
    cd glow && git checkout e66d7f855514baed8dca0d1b82d7a51151c9eef3 && cd ../ &&\
    catkin build --save-config -i --cmake-args -DCMAKE_BUILD_TYPE=Release -DOPENGL_VERSION=430 -DENABLE_NVIDIA_EXT=YES

# Download model
# 下载模型文件并解压
WORKDIR /catkin_ws/src/semantic_suma
RUN wget https://www.ipb.uni-bonn.de/html/projects/semantic_suma/darknet53.tar.gz &&\
    tar -xvf darknet53.tar.gz

# Return to the workspace directory
# 返回工作空间目录
WORKDIR /catkin_ws/src
