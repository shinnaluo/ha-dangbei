# dangbei_wol 烧录说明

固件已放在 `dist\`：

| 文件 | 地址 |
|------|------|
| `bootloader.bin` | `0x0` |
| `partition-table.bin` | `0x8000` |
| `dangbei_wol.bin` | `0x10000` |

设置：ESP32-C3 / DIO / 80MHz / 4MB

## 方式一：脚本（推荐）

1. USB 连接 ESP32-C3（需要数据线）
2. 双击 `flash.bat`，或在 PowerShell 中执行：

```powershell
cd "C:\Users\Administrator\Downloads\Root\ESP32\固件\ha-dangbei"
.\flash.ps1 -ListPorts          # 看串口
.\flash.ps1 -Port COM5          # 指定串口烧录
.\flash.ps1                     # 仅一个串口时可省略 -Port
```

首次运行会自动在本目录创建 `.esptool-venv` 并安装 esptool（需本机已装 Python 3）。

进排障：

```powershell
.\flash.ps1 -Port COM5 -Erase   # 先整片擦除再烧
```

若失败：按住 **BOOT**，点一下 **RST/EN**，再执行烧录。  
若系统无串口：先运行 `..\串口驱动\CH341SER.EXE` 安装驱动。

## 方式二：Flash Download Tool

1. 解压并运行 `..\flash_download_tool.zip` 内的 `flash_download_tool_3.9.11.exe`
2. Chip 选 **ESP32-C3**，SPI MODE **DIO**，SPI SPEED **80MHz**，FLASH SIZE **4MB**
3. 按上表加载三个 bin
4. 选 COM 口，点 START

## 烧录成功后

1. 手机连热点 `DangbeiWOL-XXXX`
2. 打开 `http://192.168.4.1/` 配 2.4G WiFi + Token
3. 投影仪保持**开机**，在 HA `Dangbei` 集成配置里填 ESP32 IP / Token 并**保存**（同步蓝牙 MAC）
4. 彻底关机后用 `remote.turn_on` 测远程开机
