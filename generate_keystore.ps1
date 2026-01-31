# 生成 Android 签名密钥的 PowerShell 脚本
# 请根据需要修改以下参数

chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$keytoolPath = "keytool"  # 如果 keytool 不在 PATH 中，请指定完整路径
$keystoreFile = "android/app/growth-keystore.p12"

# 从环境变量获取密码，如果不存在则使用默认值
$storePassword = if ($env:ANDROID_KEYSTORE_PASSWORD) { $env:ANDROID_KEYSTORE_PASSWORD } else { "your_store_password" }

$keyAlias = "growth"

# 证书信息
$dname = "CN=Growth Diary, OU=Development, O=Hancel, L=Shenzhen, ST=Guangdong, C=CN"

# 确保 android/app 目录存在
$appDir = Split-Path $keystoreFile -Parent
if (!(Test-Path $appDir)) {
    New-Item -ItemType Directory -Path $appDir -Force | Out-Null
    Write-Host "创建目录: $appDir"
}

# 生成密钥库
$command = "$keytoolPath -genkey -v -keystore $keystoreFile -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias $keyAlias -storepass $storePassword -dname `"$dname`""

Write-Host "执行命令: $command"
Invoke-Expression $command

Write-Host "密钥库生成完成！"
Write-Host "请更新 android/key.properties 文件中的密码和别名"