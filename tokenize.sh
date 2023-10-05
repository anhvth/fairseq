INPUT=$1
# python -m examples.roberta.multiprocessing_bpe_encoder \
#     --encoder-json gpt2_bpe/encoder.json \
#     --vocab-bpe gpt2_bpe/vocab.bpe \
#     --inputs $INPUT \
#     --outputs $INPUT.bpe \
#     --keep-empty \
#     --workers 60; \


python -m examples.roberta.multiprocessing_huggingface_encoder \
    --encoder-json gpt2_bpe/encoder.json \
    --vocab-bpe gpt2_bpe/vocab.bpe \
    --inputs $INPUT \
    --outputs $INPUT.bpe \
    --keep-empty \
    --workers 10; \