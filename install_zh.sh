#!/bin/bash

# Copyright (c) 2022 gouzil Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

unset GREP_OPTIONS

## purple to echo
function purple() {
    echo -e "\033[35m$1\033[0m"
}

## green to echo
function green() {
    echo -e "\033[32m$1\033[0m"
}

## Error to warning with blink
function bred() {
    echo -e "\033[31m\033[01m\033[05m$1\033[0m"
}

## Error to warning with blink
function byellow() {
    echo -e "\033[33m\033[01m\033[05m$1\033[0m"
}

## Error
function red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

## warning
function yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

path='http://paddlepaddle.org/download?url='
release_version=$(curl -s https://pypi.org/project/paddlepaddle/ | grep -E "/project/paddlepaddle/" | grep "release" | awk -F '/' '{print $(NF-1)}' | head -1)
python_list=(
    "27"
    "35"
    "36"
    "37"
    "38"
    "39"
)
# 1.环境检测
# 2.选择版本
#   * docker
#   * cpu
#   * gpu
# 3.开始安装

function checkLinuxCUDNN() {
    echo
    while true; do
        version_file='/usr/local/cuda/include/cudnn.h'
        if [[ -f "$version_file" ]]; then
            CUDNN=$(cat $version_file >/dev/null 2>&1 | grep CUDNN_MAJOR | awk 'NR==1{print $NF}')
        fi
        if [[ "$CUDNN" == "" ]]; then
            version_file=$(find /usr -name "cudnn.h" | head -1)
            CUDNN=$(cat $version_file >/dev/null 2>&1 | grep CUDNN_MAJOR -A 2 | awk 'NR==1{print $NF}')

            if [[ $CUDNN == "" ]]; then
                version_file='/usr/local/cuda/include/cudnn_version.h'
                if [[ ! -f "$version_file" ]]; then
                    CUDNN=$(cat $version_file >/dev/null 2>&1 | grep CUDNN_MAJOR | awk 'NR==1{print $NF}')
                    if [[ "$CUDNN" == "" ]]; then
                        version_file=$(find /usr -name "cudnn_version.h" | head -1)
                        CUDNN=$(cat $version_file >/dev/null 2>&1 | grep CUDNN_MAJOR -A 2 | awk 'NR==1{print $NF}')
                    fi
                fi
            fi
        fi

        if [[ "$version_file" == "" ]]; then
            echo "检测结果：未在常规路径下找到cuda/include/cudnn.h文件"
            while true; do
                read -r -p "请核实cudnn.h位置, 并在此输入路径 ( 请注意, 路径需要输入到 cudnn.h 这一级, 也有可能在 cudnn_version.h 文件下) :" cudnn_version
                echo
                if [[ "$cudnn_version" == "" ]] || [[ ! -f "$cudnn_version" ]]; then
                    read -r -p "仍未找到cuDNN, 输入y将安装CPU版本的PaddlePaddle, 输入n可重新录入cuDNN路径, 请输入 ( y/n ) " cpu_option
                    echo
                    cpu_option=$(echo $cpu_option | tr '[:upper:]' '[:lower:]')
                    if [[ "$cpu_option" == "y" ]] || [[ "$cpu_option" == "Y" ]] || [[ "$cpu_option" == "" ]]; then
                        GPU='cpu'
                        break
                    else
                        echo "请重新输入"
                        echo
                    fi
                else
                    CUDNN=$(cat $cudnn_version | grep CUDNN_MAJOR | awk 'NR==1{print $NF}')
                    echo "检测结果: 找到cudnn.h"
                    break
                fi
            done
            if [[ "$GPU" == "cpu" ]]; then
                break
            fi
        fi

        if [[ "$CUDA" == "9" ]] && [[ "$CUDNN" != "7" ]]; then
            echo
            echo "目前CUDA9下仅支持cuDNN7, 暂不支持您机器上的CUDNN${CUDNN}。您可以访问NVIDIA官网下载适合版本的CUDNN, 请ctrl+c退出安装进程。"
            echo
            if [[ "$GPU" == "cpu" ]]; then
                break
            fi
        fi

        if [[ "$CUDNN" == 5 ]] || [[ "$CUDNN" == 7 ]] || [[ "$CUDNN" == 8 ]]; then
            echo
            echo "您的CUDNN版本是: CUDNN$CUDNN"
            break
        else
            echo
            read -r -n1 -p "目前支持的CUDNN版本为5、7、8,暂不支持您机器上的CUDNN${CUDNN}, 您可以访问NVIDIA官网下载适合版本的CUDNN, 请ctrl+c退出安装进程。"
            echo
            if [[ "$GPU" == "cpu" ]]; then
                break
            fi
        fi
    done
}

function checkCUDA() {
    while true; do
        CUDA=$(echo "${CUDA_VERSION}" | awk -F "[ .]" '{print $1}')
        if [[ "$CUDA" == '' ]]; then
            if [ -f "/usr/local/cuda/version.txt" ]; then
                CUDA=$(grep </usr/local/cuda/version.txt 'CUDA Version' | awk -F '[ .]' '{print $3}')
                tmp_cuda=$CUDA
            fi
            if [ -f "/usr/local/cuda8/version.txt" ]; then
                CUDA=$(grep </usr/local/cuda8/version.txt 'CUDA Version' | awk -F '[ .]' '{print $3}')
                tmp_cuda8=$CUDA
            fi
            if [ -f "/usr/local/cuda9/version.txt" ]; then
                CUDA=$(grep </usr/local/cuda9/version.txt 'CUDA Version' | awk -F '[ .]' '{print $3}')
                tmp_cuda9=$CUDA
            fi
            if [ -f "/usr/local/cuda10/version.txt" ]; then
                CUDA=$(grep </usr/local/cuda10/version.txt 'CUDA Version' | awk -F '[ .]' '{print $3}')
                tmp_cuda10=$CUDA
            fi
            if [ -f "/usr/local/cuda11/version.txt" ]; then
                CUDA=$(grep </usr/local/cuda11/version.txt 'CUDA Version' | awk -F '[ .]' '{print $3}')
                tmp_cuda11=$CUDA
            fi
        fi

        if [ "$tmp_cuda" != "" ]; then
            echo "检测结果：找到CUDA $tmp_cuda"
        fi
        if [ "$tmp_cuda8" != "" ]; then
            echo "检测结果：找到CUDA $tmp_cuda8"
        fi
        if [ "$tmp_cuda9" != "" ]; then
            echo "检测结果：找到CUDA $tmp_cuda9"
        fi
        if [ "$tmp_cuda10" != "" ]; then
            echo "检测结果：找到CUDA $tmp_cuda10"
        fi
        if [ "$tmp_cuda11" != "" ]; then
            echo "检测结果：找到CUDA $tmp_cuda11"
        fi

        if [[ "$CUDA" == "" ]]; then
            echo "检测结果：没有在常规路径下找到cuda/version.txt文件"
            while true; do
                read -r -p "请输入cuda/version.txt的路径:" cuda_version
                if [[ "$cuda_version" == "" ]] || [[ ! -f "$cuda_version" ]]; then
                    read -r -p "仍未找到CUDA, 输入y将安装CPU版本的PaddlePaddle, 输入n可重新录入CUDA路径, 请输入 ( y/n ) " cpu_option
                    cpu_option=$(echo "$cpu_option" | tr '[:upper:]' '[:lower:]') # 这里的'[:upper:]' '[:lower:]'代表大小写判断
                    if [[ "$cpu_option" == "y" ]] || [[ "$cpu_option" == "" ]]; then
                        GPU='cpu'
                        break
                    else
                        echo "重新输入..."
                    fi
                else
                    CUDA=$(grep <"$cuda_version" 'CUDA Version' | awk -F '[ .]' '{print $3}')
                    if [ "$CUDA" == "" ]; then
                        echo "未能在version.txt中找到CUDA相关信息"
                    else
                        break
                    fi
                fi
            done
            if [ "$GPU" == "cpu" ]; then
                break
            fi
        fi

        if [[ "$CUDA" == "8" ]] || [[ "$CUDA" == "9" ]] || [[ "$CUDA" == "10" ]] || [[ "$CUDA" == "11" ]]; then
            yellow "您的CUDA版本是${CUDA}"
            nvcc -V
            break
        else
            echo "目前支持CUDA8/9/10/11, 暂不支持您的CUDA${CUDA}, 将为您安装CPU版本的PaddlePaddle"
            echo
        fi

        if [ "$GPU" == "cpu" ]; then
            break
        fi
    done
}

function checkCpuAVX() {
    echo
    echo "Step 3. 检测 CPU AVX 指令集..."
    echo
    avx=$(grep avx /proc/cpuinfo)
    if [[ $avx == '' ]]; then
        echo "此 CPU 没有 AVX 指令集"
        return
    fi
    echo "检测到 AVX 指令集"
}

function checkGPU() {
    echo
    purple "Step 4. 检测 GPU..."
    echo
    if [[ $OS == 'Macos' ]]; then
        yellow "MacOS 目前仅支持 CPU"
        return
    fi

    Gpu_Info=$(lspci | grep -i 'NVIDIA' | sed '2d' | cut -f3 -d ":" | sed 's/([^>]*)//g')
    if [[ $Gpu_Info == '' ]]; then
        yellow "未检测到支持的 GPU"
    else
        yellow "$Gpu_Info"
        checkCUDA
        checkLinuxCUDNN
    fi
}

function customPython3Path() {
    while true; do
        echo "找到 python3 版本$python_version"
        echo "安装位置为: $python_path"
        read -r -p "选择其他版本请输n (y/n): " check_python
        case $check_python in
        n)
            read -r -p "请指定您的 python3 路径:" new_python_path
            python_V=$($new_python_path -V 2>&1) # 2>/dev/null --> 2>&1
            if [ "$python_V" != "" ]; then
                python_path=$new_python_path
                python_version=$($python_path -V 2>&1 | awk -F '[ .]' 'NR==1{print $2$3}')
                echo "$python_path"
                pip_version=$($python_path -m pip -V | awk -F '[ .]' 'NR==1{print $2}')
                echo "您的 python3 版本为${python_version}"
                break
            else
                echo "输入有误,未找到 python3 路径"
            fi
            ;;
        y)
            break
            ;;
        *)
            echo "输入有误, 请重新输入."
            echo
            continue
            ;;
        esac
    done
}

function initCheckPython3() {
    echo
    purple "Step 2. 检测 python3 和 pip 版本..."
    echo
    python_path=$(which python3)
    if [ "$python_path" == '' ]; then
        while true; do
            read -r -p "没有找到默认的 python3 版本,请输入要安装的 python3 路径:" python_path
            python_path=$($python_path -V 2>&1)
            if [ "$python_path" != "" ]; then
                break
            else
                echo "输入路径有误,未找到 python3"
            fi
        done
    fi
    python_version=$($python_path -V 2>&1 | awk -F '[ .]' '{print $2$3}')
    pip_version=$($python_path -m pip -V | awk -F '[ .]' '{print $2}')
    yellow "Python3Path:   $python_path"
    echo "Python3Version:   $python_version"
    echo "PipVersion:   $pip_version"
}

function checkOS() {
    echo
    echo
    green "*****************************1. 安装环境检测*****************************"
    echo
    purple "Step 1. 正在检测您的操作系统信息..."
    echo
    SYSTEM=$(uname -s)
    if [[ "$SYSTEM" == "Darwin" ]]; then
        yellow "您的系统为: Mac OS"
        sw_vers
        OS='Macos'
    else
        yellow "您的系统为: Linux"
        OS=$(awk </etc/issue 'NR==1 {print $1}')
        if [[ $OS == "\S" ]] || [[ "$OS" == "CentOS" ]] || [[ $OS == "Ubuntu" ]]; then
            lsb_release -a
            # os='linux'
        else
            red "您的系统不在本安装包的支持范围, 如您需要在 windows 环境下安装 PaddlePaddle, 请您参考 PaddlePaddle 官网的 windows 安装文档"
        fi
    fi
}

function checkENV() {
    checkOS
    if [[ $OS != '' ]]; then
        initCheckPython3
        if [[ $OS != 'Macos' ]]; then
            checkCpuAVX
        fi
        checkGPU
    fi
    echo
}

function main() {
    echo "*********************************"
    green "欢迎使用 PaddlePaddle 快速安装脚本"
    echo "*********************************"
    echo
    yellow "如果您在安装过程中遇到任何问题, 请在 https://github.com/PaddlePaddle/Paddle/issues 反馈, 我们的工作人员将会帮您答疑解惑"
    echo
    echo "此脚本将帮助您在 Linux 或 Mac 系统下安装 PaddlePaddle"

    while true; do
        yellow "1 ) 环境检测"
        yellow "2 ) 开始安装"
        yellow "0 ) 退出"
        echo
        read -r -p "请输入序号: " Options
        case $Options in
        0)
            bred "退出安装!"
            exit 0
            ;;
        1)
            checkENV
            ;;
        2)
            checkENV
            customPython3Path
            ;;
        *)
            red "输入错误"
            ;;
        esac
    done
}
main
