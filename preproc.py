import argparse
import json
import os
from glob import glob
def process_line(line):
    json_obj = json.loads(line.strip())
    return json_obj.get('text', "") + "\n"

def preprocess_jsonl_to_txt(pair):
    input_filepath,output_filepath = pair
    with open(input_filepath, 'r', encoding='utf-8') as jsonl_file, \
         open(output_filepath, 'w', encoding='utf-8') as txt_file:
        
        for line in jsonl_file:
            txt_file.write(process_line(line))
            # Add an empty line between documents
            txt_file.write("\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert JSONL to TXT with preprocessing")
    parser.add_argument("input_folder", help="Path to the input JSONL file")
    parser.add_argument("output_folder", help="Path to the output TXT file")
    
    args = parser.parse_args()
    input_filepaths = glob(os.path.join(args.input_folder,'**/*.jsonl'), recursive=True)
    def get_output(input):
        input = input.replace(args.input_folder, args.output_folder)
        input = input.replace('.jsonl', '.txt.raw')
        os.makedirs(os.path.dirname(input))
        return input
    assert args.input_folder.endswith('/')
    assert args.output_folder.endswith('/')
    output_filepaths = [get_output(i) for i in input_filepaths]
    inputs = list(zip(input_filepaths, output_filepaths))
    print(inputs)
    # preprocess_jsonl_to_txt()
