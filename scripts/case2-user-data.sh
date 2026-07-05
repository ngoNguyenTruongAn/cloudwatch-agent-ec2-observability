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

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CONFIG_EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "CWAgent",
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "/"
        ]
      },
      "cpu": {
        "measurement": [
          "usage_idle",
          "usage_user",
          "usage_system"
        ],
        "metrics_collection_interval": 60,
        "totalcpu": true
      },
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
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/cloud-init.log",
            "log_group_name": "/ec2/cloudwatch-agent/case2/system/cloud-init",
            "log_stream_name": "{instance_id}-cloud-init",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/dnf.log",
            "log_group_name": "/ec2/cloudwatch-agent/case2/system/dnf",
            "log_stream_name": "{instance_id}-dnf",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/ec2/cloudwatch-agent/case2/nginx/access",
            "log_stream_name": "{instance_id}-access",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/ec2/cloudwatch-agent/case2/nginx/error",
            "log_stream_name": "{instance_id}-error",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
CONFIG_EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

systemctl enable amazon-cloudwatch-agent
systemctl restart amazon-cloudwatch-agent

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 \
  -a status > /tmp/cwagent-status.txt || true
