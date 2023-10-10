export CUDA_VISIBLE_DEVICES=6
export USE_FAST=1
TOTAL=2
# DATA_DIR="/mnt/nfs-data/users/anhvth5/store/data-bert-toy/data-bin/"
DATA_DIR=/mnt/nfs-data/users/anhvth5/store/data-bin
PARTS=""

for i in $(seq 1 $TOTAL); do
    PARTS="${PARTS}${DATA_DIR}/part_${i}:"
done

# Remove the trailing colon
DATA_DIR=${PARTS%:}

echo "DATA_DIR is: $DATA_DIR"

fairseq-hydra-train -m --config-dir examples/roberta/config/pretraining \
    --config-name base task.data=$DATA_DIR \
    dataset.skip_invalid_size_inputs_valid_test=True \
    checkpoint.save_interval_updates=5000 \
    dataset.disable_validation=True\
    dataset.grouped_shuffling=True \
    optimization.update_freq=[16] dataset.batch_size=16 \
    task.tokens_per_sample=512 \
    common.log_interval=1

