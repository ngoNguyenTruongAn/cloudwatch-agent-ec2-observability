---
title: "AWS-native Observability for EC2 với CloudWatch Agent"
slug: "aws-native-observability-ec2-cloudwatch-agent"
excerpt: "Thực hành xây dựng observability pipeline cho EC2 bằng CloudWatch Agent, CloudWatch Logs, CloudWatch Metrics, Alarm, SNS Email và Dashboard qua hai case thực tế: cài agent trên EC2 đã có sẵn và bootstrap agent ngay khi launch EC2 mới."
tags: ["AWS", "EC2", "CloudWatch", "Observability", "DevOps"]
coverImage: "./architecture/high-level-architecture.jpg"
status: DRAFT
metaTitle: "AWS-native Observability for EC2 với CloudWatch Agent"
metaDescription: "Hướng dẫn triển khai CloudWatch Agent cho EC2 để thu thập memory, disk, process metrics và Nginx logs, sau đó tạo dashboard, alarm và SNS email notification."
---

# AWS-native Observability for EC2 với CloudWatch Agent

Khi chạy workload trên EC2, CloudWatch mặc định chỉ cho mình một phần nhỏ bức tranh vận hành: CPU, network, disk I/O và status check. Nhưng trong thực tế DevOps/SRE, chỉ vậy là chưa đủ. Mình thường cần biết thêm memory đang dùng bao nhiêu, disk root còn trống không, process Nginx có còn chạy không, access log/error log có lỗi gì không, và khi vượt ngưỡng thì hệ thống có gửi cảnh báo hay không.

Bài lab này thực hành xây dựng một pipeline observability đơn giản nhưng thực tế cho EC2 theo hướng AWS-native bằng CloudWatch Agent.

Mình triển khai theo hai tình huống:

```text
Case 1: EC2 đã có sẵn, đang chạy Nginx, nhưng chưa có CloudWatch Agent.
Case 2: Tạo EC2 mới từ đầu và bootstrap CloudWatch Agent bằng User Data.
```

Điểm quan trọng của bài không chỉ là “cài agent”, mà là đi hết flow:

```text
EC2
→ CloudWatch Agent
→ CloudWatch Metrics
→ CloudWatch Logs
→ CloudWatch Dashboard
→ CloudWatch Alarm
→ Amazon SNS
→ Email Notification
```

---

## Kiến trúc tổng quan

![High-level Architecture](./architecture/high-level-architecture.jpg)

Trong kiến trúc này, EC2 chạy workload Nginx và CloudWatch Agent. Agent chạy bên trong instance, đọc metrics ở cấp operating system, đọc log file của Nginx, sau đó gửi dữ liệu về CloudWatch.

Luồng chính:

```text
User / Local terminal
→ AWS Systems Manager Session Manager
→ EC2 instance
→ CloudWatch Agent
→ CloudWatch Metrics / CloudWatch Logs
→ Dashboard / Alarm
→ SNS Email Notification
```

Mình không dùng SSH trong bài lab này. EC2 được truy cập bằng AWS Systems Manager Session Manager, giúp không cần mở port `22`, không cần key pair, và quản lý quyền truy cập thông qua IAM.

---

## Repository structure

Phần evidence, architecture và script nên được tách riêng để dễ review:

```text
cloudwatch-agent-ec2-observability/
├── architecture/
│   └── high-level-architecture.jpg
│
├── evidence/
│   ├── Case 1 - Existing EC2 Running.jpg
│   ├── Case 1 - IAM Role Attached.jpg
│   ├── Case 1 - SSM Managed Node.jpg
│   ├── Case 1 - CloudWatch Agent Installed.jpg
│   ├── Case 1 - Agent Running.jpg
│   ├── Case 1 - CWAgent Metrics.jpg
│   ├── Case 1 - CloudWatch Logs.jpg
│   ├── Case 1 - CloudWatch Alarm.jpg
│   ├── Case 1 - SNS Email Confirmed.jpg
│   ├── Case 1 - CloudWatch Dashboard.jpg
│   ├── Case 2 - New EC2 Running.jpg
│   ├── Case 2 - Agent Running.jpg
│   ├── Case 2 - Key CWAgent Metrics.jpg
│   ├── Case 2 - CloudWatch Log Groups.jpg
│   └── Case 2 - CloudWatch Dashboard.jpg
│
├── scripts/
│   ├── case1-cloudwatch-agent-config.json
│   ├── case2-user-data.sh
│   └── cleanup.md
│
├── 01-cloudwatch-agent-lab-evidence.md
└── 01-aws-native-observability-for-ec2-with-cloudwatch-agent.md
```

File blog này chỉ giải thích flow và kết quả chính. Phần config dài của CloudWatch Agent và User Data được đặt trong thư mục `scripts/` để dễ tái sử dụng.

---

## Các AWS service sử dụng

| Service | Vai trò |
|---|---|
| Amazon EC2 | Máy chủ chạy workload Nginx |
| CloudWatch Agent | Thu thập metrics và logs từ bên trong EC2 |
| CloudWatch Metrics | Lưu memory, disk, CPU và process metrics |
| CloudWatch Logs | Lưu Nginx access/error logs và system logs |
| CloudWatch Dashboard | Visualize các metrics quan trọng |
| CloudWatch Alarm | Cảnh báo khi metric vượt ngưỡng |
| Amazon SNS | Gửi email notification khi alarm được trigger |
| IAM Role | Cấp quyền cho EC2 gửi data lên CloudWatch |
| AWS Systems Manager | Truy cập EC2 bằng Session Manager thay vì SSH |

---

## Chuẩn bị IAM Role cho EC2

CloudWatch Agent cần quyền để gửi metrics và logs về CloudWatch. EC2 cũng cần quyền để làm việc với Systems Manager Session Manager.

Mình tạo IAM Role cho EC2:

```text
ec2-cloudwatch-agent-role
```

Attach hai managed policies:

```text
CloudWatchAgentServerPolicy
AmazonSSMManagedInstanceCore
```

Ý nghĩa:

```text
CloudWatchAgentServerPolicy
→ Cho phép CloudWatch Agent gửi metrics/logs lên CloudWatch.

AmazonSSMManagedInstanceCore
→ Cho phép EC2 xuất hiện trong Systems Manager và truy cập bằng Session Manager.
```

Evidence:

![Case 1 - IAM Role Attached](./evidence/Case%201%20-%20IAM%20Role%20Attached.jpg)

---

## Kết nối vào EC2 bằng Session Manager

Thay vì SSH, mình dùng AWS CLI từ máy local để kết nối vào EC2:

```bash
aws ssm start-session \
  --target <id-instance-ec2-của-bạn> \
  --region us-east-1
```

Ví dụ:

```bash
aws ssm start-session \
  --target i-xxxxxxxxxxxxxxxxx \
  --region us-east-1
```

Sau khi vào được EC2, chuyển sang quyền root để thao tác trong lab:

```bash
sudo su -
whoami
```

Kiểm tra OS và hostname:

```bash
hostname
cat /etc/os-release
```

Cách này giúp bài lab không cần mở SSH port `22` ra Internet.

---

# Case 1: Cài CloudWatch Agent trên EC2 đã có sẵn

## Bối cảnh

Ở case đầu tiên, mình giả định đã có một EC2 đang chạy workload Nginx. Instance này chưa từng cài CloudWatch Agent. Đây là tình huống khá thực tế: hệ thống đã chạy rồi, sau đó team DevOps/SRE muốn bổ sung observability mà không rebuild instance.

Flow thực hiện:

```text
Existing EC2
→ Attach IAM Role
→ Kiểm tra SSM Managed Node
→ Kiểm tra Nginx đang chạy
→ Xác nhận CloudWatch Agent chưa cài
→ Cài CloudWatch Agent
→ Tạo CloudWatch Agent config
→ Start CloudWatch Agent
→ Kiểm tra Metrics và Logs
→ Tạo Alarm, SNS và Dashboard
```

## Kiểm tra EC2 hiện tại

Instance dùng trong Case 1:

```text
Instance name: cwagent-existing-ec2
Instance ID: i-004d22f414fe421f0
AMI: Amazon Linux 2023
Instance type: t3.micro
VPC: CW-Agent-Ec2-vpc
Subnet: Public subnet us-east-1a
IAM Role: ec2-cloudwatch-agent-role
```

Evidence:

![Case 1 - Existing EC2 Running](./evidence/Case%201%20-%20Existing%20EC2%20Running.jpg)

EC2 cũng đã xuất hiện trong AWS Systems Manager Managed Nodes với trạng thái `Online`.

![Case 1 - SSM Managed Node](./evidence/Case%201%20-%20SSM%20Managed%20Node.jpg)

## Kiểm tra workload và trạng thái ban đầu

Sau khi kết nối vào EC2 bằng Session Manager, mình kiểm tra:

```bash
whoami
hostname
cat /etc/os-release
systemctl status nginx
rpm -qa | grep amazon-cloudwatch-agent
```

Kết quả:

```text
User hiện tại: root
OS: Amazon Linux 2023
Nginx: active running
CloudWatch Agent: chưa được cài đặt
```

Evidence:

![Case 1 - Nginx Running](./evidence/Case%201%20-%20Nginx%20Running.jpg)

![Case 1 - CloudWatch Agent Not Installed](./evidence/Case%201%20-%20CloudWatch%20Agent%20Not%20Installed.jpg)

Điều này xác nhận đúng bối cảnh: EC2 đã có workload nhưng chưa có CloudWatch Agent.

## Cài CloudWatch Agent

Cài package CloudWatch Agent trên Amazon Linux 2023:

```bash
sudo dnf install -y amazon-cloudwatch-agent
```

Kiểm tra package:

```bash
rpm -qa | grep amazon-cloudwatch-agent
ls -l /opt/aws/amazon-cloudwatch-agent/
```

Evidence:

![Case 1 - CloudWatch Agent Installed](./evidence/Case%201%20-%20CloudWatch%20Agent%20Installed.jpg)

## Tạo CloudWatch Agent config

File config được đặt tại:

```text
/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
```

File config mẫu: [Case 1 - File Agent Config](./scripts/case1-cloudwatch-agent-config.json)
---
Config này thu thập:

```text
Metrics:
- mem_used_percent
- disk_used_percent
- cpu usage metrics
- Nginx process count qua procstat

Logs:
- /var/log/nginx/access.log
- /var/log/nginx/error.log
```

Mình không đưa toàn bộ JSON config vào bài viết để bài gọn hơn. Khi cần review chi tiết, có thể mở file:

```text
./scripts/case1-cloudwatch-agent-config.json
```

Evidence:

![Case 1 - Agent Config](./evidence/Case%201%20-%20Agent%20Config.jpg)

## Start CloudWatch Agent

Start agent với config vừa tạo:

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s
```

Kiểm tra trạng thái:

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
sudo systemctl status amazon-cloudwatch-agent
```

Kết quả mong đợi:

```json
{
  "status": "running",
  "configstatus": "configured",
  "version": "1.300067.1"
}
```

Evidence:

![Case 1 - Agent Running](./evidence/Case%201%20-%20Agent%20Running.jpg)

---

## Kiểm tra CloudWatch Metrics

Sau khi agent chạy, vào CloudWatch Metrics và tìm namespace:

```text
CWAgent
```

Các metric chính được kiểm tra:

```text
mem_used_percent
disk_used_percent
procstat_lookup_pid_count
```

Ý nghĩa:

```text
mem_used_percent
→ phần trăm memory đang sử dụng.

disk_used_percent
→ phần trăm disk đã dùng ở filesystem `/`.

procstat_lookup_pid_count
→ số lượng process Nginx được CloudWatch Agent tìm thấy.
```

Evidence:

![Case 1 - CWAgent Metrics](./evidence/Case%201%20-%20CWAgent%20Metrics.jpg)

---

## Kiểm tra CloudWatch Logs

CloudWatch Agent cũng gửi Nginx logs lên CloudWatch Logs.

Log groups chính:

```text
/ec2/cloudwatch-agent/case1/nginx/access
/ec2/cloudwatch-agent/case1/nginx/error
```

Nginx access log có request `GET / HTTP/1.1`, chứng minh log file trên EC2 đã được agent đọc và gửi lên CloudWatch Logs.

Evidence:

![Case 1 - CloudWatch Logs](./evidence/Case%201%20-%20CloudWatch%20Logs.jpg)

![Case 1 - CloudWatch Logs 2](./evidence/Case%201%20-%20CloudWatch%20Logs-2.jpg)

---

## Tạo CloudWatch Alarm và SNS Email

Sau khi có metric memory, mình tạo CloudWatch Alarm trên metric:

```text
Metric: mem_used_percent
Namespace: CWAgent
Condition: Greater than threshold
Action: Send notification to SNS topic
```

Trong lab, threshold được đặt thấp để dễ trigger alarm và lấy evidence. Với môi trường production, threshold nên đặt theo baseline thực tế, ví dụ khoảng 80% hoặc 85%.

Evidence alarm:

![Case 1 - CloudWatch Alarm](./evidence/Case%201%20-%20CloudWatch%20Alarm.jpg)

Sau đó tạo SNS topic và email subscription để nhận cảnh báo.

Evidence SNS:

![Case 1 - SNS Email Confirmed](./evidence/Case%201%20-%20SNS%20Email%20Confirmed.jpg)

Khi alarm chuyển trạng thái, email notification được gửi về mailbox. Đây là phần chứng minh alerting flow hoạt động end-to-end:

```text
CloudWatch Metric
→ CloudWatch Alarm
→ SNS Topic
→ Email Notification
```

---

## Tạo CloudWatch Dashboard

Dashboard giúp visualize các metrics quan trọng của EC2.

Dashboard name:

```text
cwagent-existing-ec2-dashboard
```

Metrics hiển thị:

```text
Memory Used Percent
Nginx Process Count
Disk Used Percent
```

Evidence:

![Case 1 - CloudWatch Dashboard](./evidence/Case%201%20-%20CloudWatch%20Dashboard.jpg)

Kết quả Case 1:

```text
[✓] EC2 existing đang chạy workload Nginx
[✓] CloudWatch Agent được cài thủ công
[✓] Agent gửi metrics lên CloudWatch Metrics
[✓] Agent gửi logs lên CloudWatch Logs
[✓] Alarm được tạo và trigger
[✓] SNS gửi email notification
[✓] Dashboard hiển thị key metrics
```

---

# Case 2: Bootstrap CloudWatch Agent khi tạo EC2 mới

## Bối cảnh

Ở Case 2, mình không cài agent thủ công sau khi EC2 chạy nữa. Thay vào đó, mình dùng User Data để tự động:

```text
Cài Nginx
→ Start Nginx
→ Cài CloudWatch Agent
→ Ghi CloudWatch Agent config
→ Start CloudWatch Agent
→ Tạo request test bằng curl localhost
```

Flow:

```text
Launch new EC2
→ Attach IAM Role
→ User Data installs Nginx
→ User Data installs CloudWatch Agent
→ User Data writes config
→ User Data starts CloudWatch Agent
→ Verify Logs, Metrics and Dashboard
```

## Chuẩn bị User Data

User Data script được lưu trong repo tại: [Case 2 - User Data Script](./scripts/case2-user-data.sh)
---
Script này sẽ được copy vào phần:

```text
EC2 Launch Instance
→ Advanced details
→ User data
```

Ý tưởng chính của User Data:

```text
dnf update
→ install nginx
→ install amazon-cloudwatch-agent
→ enable/start nginx
→ write CloudWatch Agent config
→ start CloudWatch Agent
→ verify status
```

---

## Launch EC2 mới

Instance dùng trong Case 2:

```text
Instance name: cwagent-bootstrap-ec2
Instance ID: i-0dd7183a3899a9462
AMI: Amazon Linux 2023
Instance type: t3.micro
VPC: CW-Agent-Ec2-vpc
Subnet: Public subnet us-east-1a
IAM Role: ec2-cloudwatch-agent-role
```

Evidence:

![Case 2 - New EC2 Running](./evidence/Case%202%20-%20New%20EC2%20Running.jpg)

## Kiểm tra CloudWatch Agent

Sau khi EC2 boot xong, mình kết nối vào instance bằng Session Manager và kiểm tra agent:

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
sudo systemctl status amazon-cloudwatch-agent
```

Evidence:

![Case 2 - Agent Running](./evidence/Case%202%20-%20Agent%20Running.jpg)

Điều này chứng minh User Data đã tự động cài và start CloudWatch Agent khi EC2 được launch.

---

## Kiểm tra CloudWatch Logs

Case 2 tạo các log groups riêng:

```text
/ec2/cloudwatch-agent/case2/nginx/access
/ec2/cloudwatch-agent/case2/nginx/error
/ec2/cloudwatch-agent/case2/system/cloud-init
/ec2/cloudwatch-agent/case2/system/dnf
```

Nginx access log có request từ `curl http://localhost`, còn Nginx error log có startup logs của Nginx. Đây là chứng minh cho việc User Data đã chạy thành công và agent đã gửi logs lên CloudWatch.

Evidence:

![Case 2 - CloudWatch Log Groups](./evidence/Case%202%20-%20CloudWatch%20Log%20Groups.jpg)

![Case 2 - Nginx Access Log Events](./evidence/Case%202%20-%20Nginx%20Access%20Log%20Events.jpg)

![Case 2 - Nginx Error Log Events](./evidence/Case%202%20-%20Nginx%20Error%20Log%20Events.jpg)

---

## Kiểm tra CloudWatch Metrics

Trong namespace `CWAgent`, mình kiểm tra ba metrics chính của instance Case 2:

```text
mem_used_percent
disk_used_percent
procstat_lookup_pid_count
```

Evidence:

![Case 2 - Key CWAgent Metrics](./evidence/Case%202%20-%20Key%20CWAgent%20Metrics.jpg)

Kết quả này chứng minh EC2 mới được bootstrap bằng User Data đã tự động gửi metrics lên CloudWatch.

---

## Tạo Dashboard cho Case 2

Dashboard name:

```text
cwagent-bootstrap-ec2-dashboard
```

Widget hiển thị:

```text
Memory Used Percent
Nginx Process Count
Disk Used Percent
```

Evidence:

![Case 2 - CloudWatch Dashboard](./evidence/Case%202%20-%20CloudWatch%20Dashboard.jpg)

Kết quả Case 2:

```text
[✓] EC2 mới được tạo từ đầu
[✓] User Data chạy thành công
[✓] Nginx được cài và start tự động
[✓] CloudWatch Agent được cài và start tự động
[✓] Logs được gửi lên CloudWatch Logs
[✓] Metrics được gửi lên CloudWatch Metrics
[✓] Dashboard visualize được key metrics
```

---

# So sánh hai cách triển khai

| Tiêu chí | Case 1: Existing EC2 | Case 2: New EC2 from scratch |
|---|---|---|
| Tình huống | EC2 đã có sẵn | EC2 tạo mới |
| Cách cài agent | Cài thủ công sau khi EC2 đang chạy | Cài tự động bằng User Data |
| Mục tiêu | Retrofit observability | Bootstrap observability |
| Phù hợp khi | Server đã chạy trong dev/prod | Muốn server mới có monitoring ngay từ đầu |
| Evidence chính | Agent running, metrics, logs, alarm, SNS, dashboard | User Data, agent running, logs, metrics, dashboard |

Case 1 phù hợp khi mình đã có hệ thống chạy sẵn và muốn thêm observability mà không thay đổi cách launch instance.

Case 2 phù hợp khi mình muốn chuẩn hóa việc tạo EC2 mới: instance vừa boot lên là đã có Nginx, CloudWatch Agent, logs, metrics và dashboard-ready.

---

# Bài học rút ra

CloudWatch Agent là phần rất quan trọng nếu muốn quan sát EC2 sâu hơn basic monitoring.

Không có CloudWatch Agent, mình chủ yếu thấy các metric bên ngoài instance như CPU, network, disk I/O và status check. Có CloudWatch Agent, mình lấy thêm được:

```text
Memory usage
Disk usage theo filesystem
Application logs
System logs
Process status
Custom metrics trong namespace CWAgent
```

Một điểm quan trọng nữa là IAM Role nên được dùng thay vì access key. EC2 có role phù hợp thì CloudWatch Agent tự dùng quyền đó để gửi metrics/logs lên CloudWatch.

Bài lab cũng cho thấy Session Manager là lựa chọn tốt hơn SSH trong môi trường lab hoặc production cơ bản, vì không cần mở port `22` ra Internet.

---

# Cleanup

Sau khi hoàn thành lab, cần cleanup để tránh phát sinh chi phí:

```text
Terminate EC2 Case 1 nếu chỉ dùng cho lab
Terminate EC2 Case 2
Delete CloudWatch Dashboards
Delete CloudWatch Alarms
Delete SNS Topic
Delete CloudWatch Log Groups nếu không cần giữ
Delete IAM Role nếu chỉ dùng cho lab
```

---

# Kết luận

Bài lab này xây dựng một observability pipeline AWS-native cho EC2 bằng CloudWatch Agent. Qua hai case, mình kiểm chứng được cả hai hướng triển khai:

```text
Existing EC2
→ cài CloudWatch Agent thủ công
→ thêm observability cho workload đang chạy

New EC2
→ bootstrap bằng User Data
→ có observability ngay từ lúc launch
```

Khi kết hợp CloudWatch Agent với CloudWatch Metrics, CloudWatch Logs, Dashboard, Alarm và SNS, mình có thể tạo một hệ thống monitoring đơn giản, dễ hiểu, đủ thực tế cho môi trường DevOps cơ bản và có thể mở rộng tiếp cho các workload lớn hơn.
