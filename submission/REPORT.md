# Lab 16 — AWS CPU/LightGBM Report

1. Hạ tầng AWS được triển khai bằng Terraform tại `us-east-1`, gồm VPC, hai public subnet, hai private subnet, Bastion, NAT Gateway, ALB và CPU compute node.
2. Do tài khoản lab chỉ cho phép loại Free Tier, compute node dùng `c7i-flex.large` (2 vCPU, 4 GiB RAM), tương đương cấu hình CPU/RAM yêu cầu thay cho `t3.medium` bị AWS từ chối.
3. Dataset Credit Card Fraud Detection có 284.807 giao dịch, 30 features và 492 giao dịch gian lận; dữ liệu được tải từ OpenML ID 1597, là bản sao của cùng bộ ULB/Kaggle.
4. Thời gian tải dữ liệu là 0,9360 giây; thời gian huấn luyện LightGBM là 3,2974 giây và best iteration là 58.
5. Mô hình đạt AUC-ROC 0,977386 và accuracy 0,995716 trên tập test 56.962 dòng.
6. Vì dữ liệu rất mất cân bằng, recall 0,897959 quan trọng hơn accuracy; precision đạt 0,273292 và F1-score đạt 0,419048 tại threshold 0,5.
7. Median inference latency cho một dòng là 0,5370 ms; throughput cho batch 1.000 dòng đạt khoảng 610.106 dòng/giây.
8. Snapshot sau benchmark ghi nhận VM có 3,7 GiB RAM, 2 GiB swap và không có network error; Cost Explorer ngày 03/10/2026 hiển thị chi phí EC2/ELB/VPC ước tính 0 USD trong Free Tier.

Chi tiết đầy đủ nằm trong `benchmark_result.json` và `resource_usage.txt`.
