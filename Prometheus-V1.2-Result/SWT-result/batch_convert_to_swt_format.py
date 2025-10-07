#!/usr/bin/env python3
"""
批量转换多个JSON预测文件到SWT-Bench评估格式的JSONL文件。
"""

import json
import sys
import glob
from pathlib import Path
from typing import List, Dict, Any

def convert_single_file_to_swt_format(input_file: str, model_name: str = "Prometheus-Bug-Reproduction-Agent") -> List[Dict[str, Any]]:
    """
    转换单个JSON文件到SWT-Bench格式。
    
    Args:
        input_file: 输入JSON文件路径
        model_name: 模型名称
    
    Returns:
        SWT-Bench格式的预测列表
    """
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        swt_predictions = []
        
        for instance_id, prediction_data in data.items():
            # 提取补丁
            model_patch = prediction_data.get('reproduced_bug_patch', '')
            
            # 创建SWT-Bench格式条目
            swt_entry = {
                "instance_id": instance_id,
                "model_name_or_path": model_name,
                "model_patch": model_patch,
                "full_output": json.dumps(prediction_data)  # 保存完整原始数据
            }
            
            swt_predictions.append(swt_entry)
        
        return swt_predictions
    
    except Exception as e:
        print(f"Error processing {input_file}: {e}")
        return []

def batch_convert_predictions(
    input_pattern: str, 
    output_file: str, 
    model_name: str = "Prometheus-Bug-Reproduction-Agent"
) -> None:
    """
    批量转换预测文件。
    
    Args:
        input_pattern: 输入文件模式（支持glob通配符）
        output_file: 输出JSONL文件路径
        model_name: 模型名称
    """
    
    # 查找匹配的文件
    input_files = glob.glob(input_pattern)
    
    if not input_files:
        print(f"No files found matching pattern: {input_pattern}")
        return
    
    print(f"Found {len(input_files)} files to process:")
    for file in input_files:
        print(f"  - {file}")
    
    all_predictions = []
    total_instances = 0
    
    # 处理每个文件
    for input_file in input_files:
        print(f"\nProcessing: {input_file}")
        predictions = convert_single_file_to_swt_format(input_file, model_name)
        
        if predictions:
            all_predictions.extend(predictions)
            total_instances += len(predictions)
            print(f"  ✓ Converted {len(predictions)} instances")
        else:
            print(f"  ✗ No valid predictions found")
    
    # 写入JSONL文件
    if all_predictions:
        with open(output_file, 'w', encoding='utf-8') as f:
            for entry in all_predictions:
                f.write(json.dumps(entry, ensure_ascii=False) + '\n')
        
        print(f"\n✅ Successfully converted {total_instances} instances from {len(input_files)} files")
        print(f"📁 Output file: {output_file}")
        
        # 显示统计信息
        unique_instances = set(pred['instance_id'] for pred in all_predictions)
        print(f"📊 Statistics:")
        print(f"   - Total instances: {total_instances}")
        print(f"   - Unique instances: {len(unique_instances)}")
        print(f"   - Input files: {len(input_files)}")
        
    else:
        print("\n❌ No valid predictions found in any file")

def main():
    if len(sys.argv) < 2:
        print("Usage: python batch_convert_to_swt_format.py <input_pattern> [output_file] [model_name]")
        print("")
        print("Examples:")
        print("  # Convert all prediction files in current directory")
        print("  python batch_convert_to_swt_format.py 'predictions_*.json'")
        print("")
        print("  # Convert files from specific directory")
        print("  python batch_convert_to_swt_format.py '/path/to/predictions_*.json'")
        print("")
        print("  # Specify output file and model name")
        print("  python batch_convert_to_swt_format.py 'predictions_*.json' 'all_predictions.jsonl' 'MyModel'")
        print("")
        print("  # Convert specific files")
        print("  python batch_convert_to_swt_format.py 'predictions_20251003_*.json'")
        sys.exit(1)
    
    input_pattern = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else "swt_batch_predictions.jsonl"
    model_name = sys.argv[3] if len(sys.argv) > 3 else "Prometheus-Bug-Reproduction-Agent"
    
    print(f"🔄 Batch converting predictions...")
    print(f"📂 Input pattern: {input_pattern}")
    print(f"📁 Output file: {output_file}")
    print(f"🤖 Model name: {model_name}")
    print("-" * 50)
    
    batch_convert_predictions(input_pattern, output_file, model_name)

if __name__ == "__main__":
    main()
