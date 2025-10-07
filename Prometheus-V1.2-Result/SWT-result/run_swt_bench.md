# 步骤
## 转换格式
将/root/fzw/Prometheus-Bug-Reproduction-Agent/predictions_20251003_223252.json转换成swt-bench测试脚本需要的格式
``` 
python convert_to_swtformat.py Prometheus-Bug-Reproduction-Agent/predictions_20251003_223252.json
```

## 激活环境
``` 
cd /root/fzw/swt-bench && conda activate swt-bench
``` 

## 运行评估
``` 
python -m src.main \
    --dataset_name princeton-nlp/SWE-bench_Lite \
    --predictions_path /root/fzw/Prometheus-Bug-Reproduction-Agent/swt_predictions_20251003_223252.jsonl \
    --max_workers 1 \
    --run_id my_evaluation
``` 

## 查看结果
``` 
/root/fzw/swt-bench/evaluation_results/Prometheus-Bug-Reproduction-Agent.my_evaluation.json
``` 