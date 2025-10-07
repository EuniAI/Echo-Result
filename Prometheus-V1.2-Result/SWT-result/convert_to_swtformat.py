#!/usr/bin/env python3
"""
Convert predictions from nested JSON format to SWT-Bench evaluation format.
"""

import json
import sys
from pathlib import Path

def convert_predictions_to_swt_format(input_file, output_file, model_name="Prometheus-Bug-Reproduction-Agent"):
    """
    Convert predictions from nested JSON format to SWT-Bench JSONL format.
    
    Args:
        input_file: Path to input JSON file with nested structure
        output_file: Path to output JSONL file
        model_name: Name of the model/approach
    """
    
    # Read the input JSON file
    with open(input_file, 'r') as f:
        data = json.load(f)
    
    # Convert to SWT-Bench format
    swt_predictions = []
    
    for instance_id, prediction_data in data.items():
        # Extract the patch from the nested structure
        model_patch = prediction_data.get('reproduced_bug_patch', '')
        
        # Create SWT-Bench format entry
        swt_entry = {
            "instance_id": instance_id,
            "model_name_or_path": model_name,
            "model_patch": model_patch,
            "full_output": json.dumps(prediction_data)  # Store full original data as full_output
        }
        
        swt_predictions.append(swt_entry)
    
    # Write to JSONL format
    with open(output_file, 'w') as f:
        for entry in swt_predictions:
            f.write(json.dumps(entry) + '\n')
    
    print(f"Converted {len(swt_predictions)} predictions from {input_file} to {output_file}")
    print(f"Model name: {model_name}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python convert_to_swt_format_complete.py <input_json_file> [output_jsonl_file] [model_name]")
        print("Example: python convert_to_swt_format_complete.py predictions_20251003_223252.json")
        print("         python convert_to_swt_format_complete.py predictions_20251003_223252.json swt_predictions.jsonl MyModel")
        sys.exit(1)
    
    input_file = sys.argv[1]
    
    # Default output file with swt prefix in the same directory
    if len(sys.argv) > 2:
        output_file = sys.argv[2]
    else:
        input_path = Path(input_file)
        output_file = input_path.parent / f"swt_{input_path.stem}.jsonl"
    
    model_name = sys.argv[3] if len(sys.argv) > 3 else "Prometheus-Bug-Reproduction-Agent"
    
    if not Path(input_file).exists():
        print(f"Error: Input file {input_file} does not exist")
        sys.exit(1)
    
    convert_predictions_to_swt_format(input_file, output_file, model_name)

if __name__ == "__main__":
    main()