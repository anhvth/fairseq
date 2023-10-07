export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7

DATA_DIR=/raid/kilm-raw/data-bin/part_1/
# CKPT=$(pwd)/phobert/PhoBERT_base_fairseq/model.pt
fairseq-hydra-train -m --config-dir examples/roberta/config/pretraining \
    --config-name base task.data=$DATA_DIR \
    dataset.skip_invalid_size_inputs_valid_test=True \
    checkpoint.save_interval_updates=1000 


#DATA_DIR=$(pwd)/data-bin/kilm-raw-tiny/data-bin/
#CKPT=$(pwd)/phobert/PhoBERT_base_fairseq/model.pt
#fairseq-hydra-train -m --config-dir examples/roberta/config/pretraining \
#--config-name base task.data=$DATA_DIR checkpoint.finetune_from_model=$CKPT \
#checkpoint.save_interval_updates=10000 dataset.skip_invalid_size_inputs_valid_test=True 

