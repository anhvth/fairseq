export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7


DATA_DIR="/raid/kilm-raw/data-bin/"
TOTAL=199

PARTS=""

for i in $(seq 1 $TOTAL); do
    #if [ "$i" -eq 59 ] || [ "$i" -eq 72 ]; then
    #    continue
    #fi
    PARTS="${PARTS}${DATA_DIR}/part_${i}:"
done

# Remove the trailing colon
DATA_DIR=${PARTS%:}

echo "DATA_DIR is: $DATA_DIR"
# CKPT=multirun/2023-10-08/10-44-31/0/checkpoints/checkpoint_last.pt
#CKPT= /mnt/nfs-data/users/anhvth5/fairseq/multirun/2023-10-08/07-11-02/

fairseq-hydra-train -m --config-dir examples/roberta/config/pretraining \
    --config-name large task.data=$DATA_DIR \
    dataset.skip_invalid_size_inputs_valid_test=True \
    checkpoint.save_interval_updates=5000 \
    dataset.disable_validation=True\
    dataset.grouped_shuffling=True \
    optimization.update_freq=[8] dataset.batch_size=32 \
    task.tokens_per_sample=512
#    checkpoint.restore_file=/mnt/nfs-data/users/anhvth5/fairseq/multirun/2023-10-07/18-46-56/0/checkpoints/checkpoint_9_5000.pt\


#    checkpoint.restore_file=$(pwd)/$CKPT \

