#!/bin/bash

# 导入被测试的函数
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/../utils/utils.sh"

# 测试目录设置
TEST_DIR="/tmp/download_test"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# 测试计数器
tests_total=0
tests_passed=0

# 测试辅助函数
assert() {
    local expected=$1
    local actual=$2
    local message=$3
    
    ((tests_total++))
    if [ "$expected" = "$actual" ]; then
        echo "✅ $message"
        ((tests_passed++))
    else
        echo "❌ $message (expected: $expected, got: $actual)"
    fi
}

# 测试用例1：成功下载文件
test_successful_download() {
    local test_file="images.tar.gz"
    download_file "$test_file"
    local status=$?
    assert "0" "$status" "Test successful download"
}

# 测试用例2：下载不存在的文件
test_nonexistent_file() {
    local test_file="nonexistent_file_12345.txt"
    download_file "$test_file"
    local status=$?
    assert "1" "$status" "Test nonexistent file download"
}

# 执行测试
echo "开始测试 download_file 函数..."
test_successful_download
test_nonexistent_file

# 输出测试结果统计
echo "测试完成: $tests_passed/$tests_total 通过"

# 清理测试环境
cd - > /dev/null
rm -rf "$TEST_DIR"

# 根据测试结果设置退出码
[ "$tests_passed" -eq "$tests_total" ] || exit 1
