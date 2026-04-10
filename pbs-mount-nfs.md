一、去掉登录订阅弹窗（适用于 PBS 4.1.0）
# 备份原文件
cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js \
   /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak

# 去掉弹窗
sed -i "s/res.data.status.toLowerCase() !== 'active'/false/" \
  /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js



1. 安装NFS客户端
apt-get install nfs-common

2. 创建挂载点
mkdir -p /mnt/nas_storage

3. 测试手动挂载
mount -t nfs 192.168.2.11:/volume1/storage500GB1 /mnt/nas_storage
验证是否成功
df -h | grep nas_storage
ls /mnt/nas_storage

4. 设置开机自动挂载（/etc/fstab）
vi /etc/fstab
添加：
192.168.2.11:/volume1/storage500GB1  /mnt/nas_storage  nfs  defaults,_netdev,rw,hard,intr,timeo=30,retrans=3  0  0
关键参数说明：
_netdev — 等网络就绪后再挂载（PBS服务器重要）
hard,intr — 网络中断时不丢失任务
timeo=30 — 超时30秒重试
retrans=3 — 重试3次

5.PBS Datastore创建成功 nas-storage → /mnt/nas_storage/pbs-datastore
# 创建空目录
mkdir -p /mnt/nas_storage/pbs-datastore
# 创建Datastore
proxmox-backup-manager datastore create nas-storage /mnt/nas_storage/pbs-datastore
chown -R backup:backup /mnt/nas_storage/pbs-datastore
chmod -R 755 /mnt/nas_storage/pbs-datastore

6.PVE Web界面 → 数据中心 → 存储 → 添加 → Proxmox Backup Server
ID：nas-backup
服务器：pbs服务器ip，根据实际情况填写
Datastore：nas-storage
用户名：root@pam，必须加上@pam
密码：PBS的root密码，根据实际情况填写
指纹：根据实际情况填写


PBS：调整精简&GC作业即可。
PVE：设置备份计划即可。
