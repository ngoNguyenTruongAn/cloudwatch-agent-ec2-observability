# AWS-native Observability cho EC2 với CloudWatch Agent

Repository này chứa bài lab thực hành triển khai **AWS-native observability cho EC2** bằng **Amazon CloudWatch Agent**.

Bài lab mô phỏng cách thu thập system metrics, application logs, process metrics, tạo dashboard, cấu hình alarm và gửi email notification bằng các dịch vụ AWS-native.

---

## Tổng quan

Mặc định, EC2 basic monitoring chỉ cung cấp một số thông tin cơ bản như:

- CPU utilization
- Network traffic
- Disk I/O
- Status checks

Tuy nhiên, trong thực tế vận hành, DevOps/SRE thường cần quan sát sâu hơn bên trong instance, ví dụ:

- Memory usage
- Disk usage theo filesystem
- Application logs
- System logs
- Trạng thái process
- Custom metrics
- Alerting và notification

Trong bài lab này, mình sử dụng **CloudWatch Agent** để thu thập các tín hiệu đó từ EC2 và gửi về **CloudWatch Metrics** và **CloudWatch Logs**.

---

## Vì sao cần CloudWatch Agent?

EC2 basic monitoring chủ yếu quan sát instance từ bên ngoài. Vì vậy CloudWatch có thể thấy các metric như CPU, network, disk I/O và status check.

Nhưng các thông tin nằm bên trong operating system như memory đang dùng bao nhiêu, filesystem còn trống bao nhiêu, application log ghi gì, hoặc process Nginx còn chạy hay không thì CloudWatch không tự thấy được nếu chỉ dùng basic monitoring.

CloudWatch Agent giải quyết khoảng trống đó bằng cách chạy bên trong EC2 instance. Agent đọc metrics và logs từ hệ điều hành, sau đó gửi dữ liệu về CloudWatch Metrics và CloudWatch Logs.

```text
EC2 basic monitoring
→ nhìn từ bên ngoài instance

CloudWatch Agent
→ nhìn được bên trong operating system
```

---

## Phạm vi bài lab

Bài lab gồm 2 tình huống thực tế.

### Case 1: EC2 đã có sẵn

Một EC2 instance đã chạy workload, nhưng chưa được cài CloudWatch Agent.

Mục tiêu:

```text
Cài đặt và cấu hình CloudWatch Agent trên EC2 đã tồn tại.
```

Flow:

```text
Existing EC2
→ Attach IAM Role
→ Kiểm tra Systems Manager access
→ Kiểm tra Nginx đang chạy
→ Xác nhận CloudWatch Agent chưa cài
→ Cài CloudWatch Agent
→ Tạo CloudWatch Agent config
→ Start CloudWatch Agent
→ Kiểm tra CloudWatch Metrics
→ Kiểm tra CloudWatch Logs
→ Tạo CloudWatch Alarm
→ Gửi SNS Email Notification
→ Tạo CloudWatch Dashboard
```

### Case 2: Tạo EC2 mới từ đầu

Một EC2 instance mới được launch từ đầu và CloudWatch Agent được cài tự động trong quá trình bootstrap.

Mục tiêu:

```text
Bootstrap Nginx và CloudWatch Agent bằng EC2 User Data.
```

Flow:

```text
Launch new EC2
→ Attach IAM Role
→ User Data cài Nginx
→ User Data cài CloudWatch Agent
→ User Data ghi agent config
→ User Data start CloudWatch Agent
→ Kiểm tra CloudWatch Metrics
→ Kiểm tra CloudWatch Logs
→ Tạo CloudWatch Dashboard
```

---

## Kiến trúc

High-level architecture:

```text
Local Terminal
→ AWS CLI / Session Manager
→ EC2 with CloudWatch Agent
→ CloudWatch Metrics
→ CloudWatch Logs
→ CloudWatch Dashboard
→ CloudWatch Alarm
→ Amazon SNS
→ Email Notification
```

Architecture diagram:

![High-level Architecture](./architecture/high-level-architecture.jpg)

---

## AWS Services sử dụng

| Service | Vai trò |
|---|---|
| Amazon EC2 | Máy chủ chạy workload Nginx |
| Amazon CloudWatch Agent | Thu thập metrics và logs từ bên trong EC2 |
| CloudWatch Metrics | Lưu memory, disk, CPU và process metrics |
| CloudWatch Logs | Lưu application logs và system logs |
| CloudWatch Dashboard | Visualize các metric quan trọng |
| CloudWatch Alarms | Kích hoạt cảnh báo khi metric vượt ngưỡng |
| Amazon SNS | Gửi email notification |
| IAM Role | Cấp quyền cho EC2 gửi metrics/logs lên CloudWatch |
| AWS Systems Manager | Quản lý và truy cập EC2 không cần SSH |
| Session Manager | Kết nối vào EC2 từ máy local |
| Nginx | Workload mẫu dùng trong bài lab |

---

## Cấu trúc repository

```text
cloudwatch-agent-ec2-observability/
├── architecture/
│   └── high-level-architecture.jpg
│
├── evidence/
│   ├── Case 1 - Existing EC2 Running.jpg
│   ├── Case 1 - IAM Role Attached.jpg
│   ├── Case 1 - SSM Managed Node.jpg
│   ├── Case 1 - OS Check.jpg
│   ├── Case 1 - Nginx Running.jpg
│   ├── Case 1 - CloudWatch Agent Not Installed.jpg
│   ├── Case 1 - CloudWatch Agent Installed.jpg
│   ├── Case 1 - Agent Config.jpg
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
│   ├── Case 2 - Nginx Access Log Events.jpg
│   ├── Case 2 - Nginx Error Log Events.jpg
│   └── Case 2 - CloudWatch Dashboard.jpg
│
├── scripts/
│   ├── case1-cloudwatch-agent-config.json
│   ├── case2-user-data.sh
│   └── cleanup.md
│
├── 01-cloudwatch-agent-lab-evidence.md
├── 01-aws-native-observability-for-ec2-with-cloudwatch-agent.md
├── README.md
└── .gitignore
```

---

## Các file chính

| File | Mô tả |
|---|---|
| `01-cloudwatch-agent-lab-evidence.md` | File evidence step-by-step của bài lab |
| `01-aws-native-observability-for-ec2-with-cloudwatch-agent.md` | Blog draft được viết lại từ bài lab |
| `scripts/case1-cloudwatch-agent-config.json` | CloudWatch Agent config cho Case 1 |
| `scripts/case2-user-data.sh` | User Data script để bootstrap EC2 ở Case 2 |
| `scripts/cleanup.md` | Checklist cleanup sau khi hoàn thành lab |

---

## Yêu cầu trước khi chạy lab

Trước khi thực hiện bài lab, cần chuẩn bị:

- Một AWS account
- AWS CLI đã được cài trên máy local
- AWS CLI đã được cấu hình credentials hợp lệ
- Session Manager Plugin đã được cài
- Hiểu cơ bản về EC2, IAM và CloudWatch
- Region sử dụng cho bài lab, ví dụ: `us-east-1`

Kiểm tra AWS CLI:

```bash
aws --version
```

Kiểm tra AWS identity:

```bash
aws sts get-caller-identity
```

Kiểm tra Session Manager Plugin:

```bash
session-manager-plugin
```

---

## IAM Role

EC2 instances trong bài lab sử dụng IAM Role thay vì access key.

Tên role đề xuất:

```text
ec2-cloudwatch-agent-role
```

Managed policies cần attach:

```text
CloudWatchAgentServerPolicy
AmazonSSMManagedInstanceCore
```

Ý nghĩa:

| Policy | Vai trò |
|---|---|
| `CloudWatchAgentServerPolicy` | Cho phép CloudWatch Agent gửi metrics và logs lên CloudWatch |
| `AmazonSSMManagedInstanceCore` | Cho phép EC2 được quản lý bằng AWS Systems Manager |

---

## Cách truy cập EC2

Bài lab sử dụng **AWS Systems Manager Session Manager** thay vì SSH.

Security Group đề xuất:

```text
Inbound:
- HTTP 80 từ My IP nếu cần test Nginx bằng browser
- Không mở SSH 22

Outbound:
- Allow all outbound
```

Lý do dùng Session Manager:

- Không cần SSH key pair
- Không cần mở port `22`
- Có thể kiểm soát truy cập bằng IAM
- Phù hợp với hướng vận hành AWS-native
- Giảm bề mặt tấn công public

Kết nối vào EC2 từ terminal máy local:

```bash
aws ssm start-session \
  --target <your-ec2-instance-id> \
  --region us-east-1
```

Sau khi kết nối:

```bash
sudo su -
whoami
hostname
cat /etc/os-release
```

---

## Chi phí và Log Retention

CloudWatch Agent có thể phát sinh chi phí tùy theo:

- Số lượng custom metrics
- Số lượng dimension của metrics
- Tần suất gửi metrics
- Số lượng log events
- Thời gian lưu CloudWatch Logs

Trong bài lab này, các metric như memory, disk và Nginx process count được gửi vào namespace `CWAgent`. Đây là custom metrics, vì vậy cần kiểm soát số lượng metric/dimension ngay từ đầu.

Mình dùng interval 60 giây:

```text
metrics_collection_interval: 60
```

Nếu giảm xuống 10 giây, dữ liệu sẽ chi tiết hơn nhưng số lượng datapoint tăng lên và có thể làm tăng chi phí.

Với CloudWatch Logs, nếu không cấu hình retention, log group có thể giữ log vô thời hạn. Nên đặt retention policy sau khi log group được tạo.

Ví dụ đặt retention 7 ngày cho Case 1:

```bash
aws logs put-retention-policy \
  --log-group-name "/ec2/cloudwatch-agent/case1/nginx/access" \
  --retention-in-days 7 \
  --region us-east-1

aws logs put-retention-policy \
  --log-group-name "/ec2/cloudwatch-agent/case1/nginx/error" \
  --retention-in-days 7 \
  --region us-east-1
```

Ví dụ đặt retention 7 ngày cho Case 2:

```bash
aws logs put-retention-policy \
  --log-group-name "/ec2/cloudwatch-agent/case2/nginx/access" \
  --retention-in-days 7 \
  --region us-east-1

aws logs put-retention-policy \
  --log-group-name "/ec2/cloudwatch-agent/case2/nginx/error" \
  --retention-in-days 7 \
  --region us-east-1

aws logs put-retention-policy \
  --log-group-name "/ec2/cloudwatch-agent/case2/system/cloud-init" \
  --retention-in-days 7 \
  --region us-east-1

aws logs put-retention-policy \
  --log-group-name "/ec2/cloudwatch-agent/case2/system/dnf" \
  --retention-in-days 7 \
  --region us-east-1
```

Trong production, retention nên được chọn theo nhu cầu audit, compliance và chi phí, ví dụ 7 ngày, 14 ngày, 30 ngày hoặc lâu hơn.

---

## Case 1: EC2 đã có sẵn

### Mục tiêu

Cài CloudWatch Agent trên một EC2 instance đã tồn tại và đang chạy workload.

### Thông tin instance ví dụ

```text
Instance name: cwagent-existing-ec2
AMI: Amazon Linux 2023
Instance type: t3.micro
IAM Role: ec2-cloudwatch-agent-role
Access method: AWS Systems Manager Session Manager
```

### Cài CloudWatch Agent

```bash
sudo dnf install -y amazon-cloudwatch-agent
```

Kiểm tra cài đặt:

```bash
rpm -qa | grep amazon-cloudwatch-agent
ls -l /opt/aws/amazon-cloudwatch-agent/
```

### CloudWatch Agent Config

File config được lưu trong repository tại:

```text
scripts/case1-cloudwatch-agent-config.json
```

Trên EC2 instance, file config được đặt tại:

```text
/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
```

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

Phần cốt lõi của config là `procstat` và `logs`.

Ví dụ `procstat` để theo dõi process Nginx:

```json
{
  "procstat": [
    {
      "exe": "nginx",
      "measurement": [
        "pid_count",
        "cpu_usage",
        "memory_rss"
      ],
      "metrics_collection_interval": 60
    }
  ]
}
```

Ví dụ log collection cho Nginx access log:

```json
{
  "file_path": "/var/log/nginx/access.log",
  "log_group_name": "/ec2/cloudwatch-agent/case1/nginx/access",
  "log_stream_name": "{instance_id}-access",
  "timezone": "UTC"
}
```

### Start CloudWatch Agent

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s
```

Kiểm tra trạng thái:

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 \
  -a status
```

Hoặc:

```bash
sudo systemctl status amazon-cloudwatch-agent
```

### Metrics thu thập

Bài lab thu thập metrics trong namespace `CWAgent`:

| Metric | Ý nghĩa |
|---|---|
| `mem_used_percent` | Phần trăm memory đã sử dụng |
| `disk_used_percent` | Phần trăm disk đã sử dụng |
| `procstat_lookup_pid_count` | Số lượng process Nginx |
| `cpu_usage_idle` | Phần trăm CPU idle |
| `cpu_usage_user` | Phần trăm CPU user |
| `cpu_usage_system` | Phần trăm CPU system |

### Vì sao Nginx Process Count có thể lớn hơn 1?

Metric `procstat_lookup_pid_count` cho biết số process Nginx mà CloudWatch Agent tìm thấy.

Với Nginx, giá trị này thường lớn hơn `1` vì Nginx thường chạy theo mô hình:

```text
1 master process
+ N worker processes
```

Ví dụ nếu dashboard hiển thị:

```text
Nginx Process Count = 3
```

Điều đó có thể hiểu là Nginx đang có 1 master process và 2 worker processes. Đây là trạng thái bình thường, không phải lỗi.

### Logs thu thập

Nginx logs được gửi lên CloudWatch Logs:

```text
/ec2/cloudwatch-agent/case1/nginx/access
/ec2/cloudwatch-agent/case1/nginx/error
```

### Alarm và Notification

CloudWatch Alarm được tạo từ metric `mem_used_percent`.

Threshold dùng trong lab:

```text
Metric: mem_used_percent
Condition: Greater than 25
Evaluation: 1 out of 1 datapoint
Action: Send notification to SNS topic
```

Trong môi trường production, threshold nên cao hơn, ví dụ `80` hoặc `85`, tùy baseline workload.

Khi cấu hình alarm, cần chú ý thêm:

| Thuộc tính | Ý nghĩa |
|---|---|
| `Period` | Khoảng thời gian gom dữ liệu cho mỗi datapoint |
| `Evaluation periods` | Số datapoint được dùng để đánh giá alarm |
| `Datapoints to alarm` | Số datapoint cần vượt ngưỡng để chuyển sang `ALARM` |
| `TreatMissingData` | Cách xử lý khi metric không gửi dữ liệu |

Ví dụ production nên dùng:

```text
Period: 5 minutes
Evaluation periods: 3
Datapoints to alarm: 2 out of 3
```

Cách này giúp giảm false alarm do spike ngắn. `TreatMissingData` cũng quan trọng vì nếu agent ngừng gửi metric, alarm có thể chuyển sang hoặc bị kẹt ở trạng thái `INSUFFICIENT_DATA`.

### Dashboard

Dashboard name:

```text
cwagent-existing-ec2-dashboard
```

Các metrics chính hiển thị:

```text
Memory Used Percent
Nginx Process Count
Disk Used Percent
```

---

## Case 2: Tạo EC2 mới từ đầu

### Mục tiêu

Launch một EC2 instance mới và tự động cài Nginx + CloudWatch Agent bằng User Data.

### Thông tin instance ví dụ

```text
Instance name: cwagent-bootstrap-ec2
AMI: Amazon Linux 2023
Instance type: t3.micro
IAM Role: ec2-cloudwatch-agent-role
Access method: AWS Systems Manager Session Manager
```

### User Data

User Data script được lưu tại:

```text
scripts/case2-user-data.sh
```

Script này thực hiện:

```text
Cài Nginx
Cài CloudWatch Agent
Start Nginx
Tạo file index.html để test
Tạo request test để sinh Nginx access log
Ghi CloudWatch Agent config
Start CloudWatch Agent
Enable CloudWatch Agent service
```

Một phần quan trọng của User Data:

```bash
#!/bin/bash
set -euxo pipefail

dnf update -y
dnf install -y nginx amazon-cloudwatch-agent

systemctl enable nginx
systemctl start nginx

echo "Bootstrap EC2 for CloudWatch Agent lab" > /usr/share/nginx/html/index.html

curl http://localhost || true
curl http://localhost || true
curl http://localhost || true
```

Đoạn cuối của User Data start CloudWatch Agent bằng config vừa ghi:

```bash
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

systemctl enable amazon-cloudwatch-agent
systemctl restart amazon-cloudwatch-agent
```

### Kiểm tra CloudWatch Agent

Kết nối vào EC2:

```bash
aws ssm start-session \
  --target <your-case2-ec2-instance-id> \
  --region us-east-1
```

Kiểm tra trạng thái CloudWatch Agent:

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 \
  -a status
```

Kết quả mong đợi:

```json
{
  "status": "running",
  "configstatus": "configured",
  "version": "1.x"
}
```

### Metrics thu thập

Case 2 cũng gửi metrics vào namespace `CWAgent`:

```text
mem_used_percent
disk_used_percent
procstat_lookup_pid_count
```

### Logs thu thập

Case 2 tạo các CloudWatch Logs groups riêng:

```text
/ec2/cloudwatch-agent/case2/nginx/access
/ec2/cloudwatch-agent/case2/nginx/error
/ec2/cloudwatch-agent/case2/system/cloud-init
/ec2/cloudwatch-agent/case2/system/dnf
```

### Dashboard

Dashboard name:

```text
cwagent-bootstrap-ec2-dashboard
```

Các metrics chính hiển thị:

```text
Memory Used Percent
Nginx Process Count
Disk Used Percent
```

---

## Tổng hợp evidence

### Evidence Case 1

| Evidence | Ý nghĩa |
|---|---|
| Existing EC2 Running | Chứng minh EC2 đã chạy |
| IAM Role Attached | Chứng minh EC2 có quyền cần thiết |
| SSM Managed Node | Chứng minh EC2 có thể truy cập không cần SSH |
| Nginx Running | Chứng minh workload đang chạy |
| CloudWatch Agent Not Installed | Chứng minh đây là EC2 có sẵn chưa cài agent |
| CloudWatch Agent Installed | Chứng minh agent được cài thành công |
| Agent Running | Chứng minh agent đang chạy |
| CWAgent Metrics | Chứng minh metrics được gửi lên CloudWatch |
| CloudWatch Logs | Chứng minh logs được gửi lên CloudWatch Logs |
| CloudWatch Alarm | Chứng minh alerting đã được cấu hình |
| SNS Email Confirmed | Chứng minh email notification hoạt động |
| CloudWatch Dashboard | Chứng minh metrics được visualize |

### Evidence Case 2

| Evidence | Ý nghĩa |
|---|---|
| New EC2 Running | Chứng minh EC2 mới đã được launch |
| Agent Running | Chứng minh User Data đã cài và start agent |
| Key CWAgent Metrics | Chứng minh metrics được gửi tự động |
| CloudWatch Log Groups | Chứng minh log groups được tạo |
| Nginx Access Log Events | Chứng minh Nginx access logs được ship |
| Nginx Error Log Events | Chứng minh Nginx error logs được ship |
| CloudWatch Dashboard | Chứng minh metrics được visualize |

---

## Kết quả đạt được

Sau khi hoàn thành bài lab:

```text
[✓] EC2 metrics được thu thập bởi CloudWatch Agent
[✓] Memory usage hiển thị trong CloudWatch
[✓] Disk usage hiển thị trong CloudWatch
[✓] Nginx process count hiển thị trong CloudWatch
[✓] Nginx logs được gửi lên CloudWatch Logs
[✓] CloudWatch Dashboard được tạo
[✓] CloudWatch Alarm được tạo
[✓] SNS Email Notification được confirm
[✓] Truy cập EC2 bằng Session Manager thay vì SSH
[✓] Hoàn thành cả 2 case: existing EC2 và new EC2 bootstrap
```

---

## Bài học rút ra

CloudWatch Agent giúp mở rộng khả năng observability cho EC2 vượt xa EC2 basic monitoring mặc định.

Nếu không có CloudWatch Agent, EC2 basic monitoring chủ yếu cung cấp:

```text
CPUUtilization
NetworkIn / NetworkOut
DiskReadOps / DiskWriteOps
StatusCheckFailed
```

Khi có CloudWatch Agent, ta có thể thu thập thêm:

```text
Memory usage
Disk usage
Application logs
System logs
Process metrics
Custom metrics
```

Bài lab cũng cho thấy 2 pattern vận hành thực tế:

| Pattern | Khi nào dùng |
|---|---|
| Cài agent trên EC2 đã có sẵn | Khi server đã chạy trước đó |
| Bootstrap agent bằng User Data | Khi launch EC2 mới và muốn có monitoring ngay từ đầu |

---

## Cleanup

Để tránh phát sinh chi phí không cần thiết, cần cleanup các tài nguyên sau khi hoàn thành lab:

- Terminate EC2 instances dùng cho lab
- Xóa CloudWatch Dashboards
- Xóa CloudWatch Alarms
- Xóa SNS Topics và subscriptions
- Xóa CloudWatch Log Groups nếu không cần giữ lại
- Xóa IAM Role nếu chỉ tạo cho bài lab này
- Xóa security groups không dùng nữa
- Xóa VPC resources nếu chỉ tạo riêng cho bài lab

Có thể xóa log group bằng CLI nếu không cần giữ evidence:

```bash
aws logs delete-log-group \
  --log-group-name "/ec2/cloudwatch-agent/case1/nginx/access" \
  --region us-east-1
```

---

## Ghi chú production

Repository này phục vụ mục đích học tập và demo.

Nếu áp dụng cho production, nên cân nhắc:

- Cấu hình log retention policy phù hợp
- Dùng IAM policy theo nguyên tắc least privilege
- Đặt CloudWatch Alarm threshold thực tế hơn
- Quản lý CloudWatch Agent config bằng SSM Parameter Store
- Tự động hóa bằng Terraform, CloudFormation hoặc SSM State Manager
- Tránh public inbound access nếu không cần thiết
- Dùng private subnet và VPC endpoints khi phù hợp

---

## Tác giả

Bài này được thực hiện trong quá trình học AWS DevOps / Observability.

```text
Topic: AWS-native Observability for EC2
Author: Ngô Nguyễn Trường An
Main tool: Amazon CloudWatch Agent
Access method: AWS Systems Manager Session Manager
```
