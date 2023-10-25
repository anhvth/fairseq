# Textless speech emotion conversion using decomposed and discrete representations
[Felix Kreuk](https://felixkreuk.github.io), Adam Polyak, Jade Copet, Eugene Kharitonov, Tu-Anh Nguyen, Morgane Rivière, Wei-Ning Hsu, Abdelrahman Mohamed, Emmanuel Dupoux, [Yossi Adi](https://adiyoss.github.io)

_abstract_: Speech emotion conversion is the task of modifying the perceived emotion of a speech utterance while preserving the lexical content and speaker identity. In this study, we cast the problem of emotion conversion as a spoken language translation task. We decompose speech into discrete and disentangled learned representations, consisting of content units, F0, speaker, and emotion. First, we modify the speech content by translating the content units to a target emotion, and then predict the prosodic features based on these units. Finally, the speech waveform is generated by feeding the predicted representations into a neural vocoder. Such a paradigm allows us to go beyond spectral and parametric changes of the signal, and model non-verbal vocalizations, such as laughter insertion, yawning removal, etc. We demonstrate objectively and subjectively that the proposed method is superior to the baselines in terms of perceived emotion and audio quality. We rigorously evaluate all components of such a complex system and conclude with an extensive model analysis and ablation study to better emphasize the architectural choices, strengths and weaknesses of the proposed method. Samples and code will be publicly available under the following link: https://speechbot.github.io/emotion.

## Installation
First, create a conda virtual environment and activate it:
```
conda create -n emotion python=3.8 -y
conda activate emotion
```

Then, clone this repository:
```
git clone https://github.com/facebookresearch/fairseq.git
cd fairseq/examples/emotion_conversion
git clone https://github.com/felixkreuk/speech-resynthesis
```

Next, download the EmoV discrete tokens:
```
wget https://dl.fbaipublicfiles.com/textless_nlp/emotion_conversion/data.tar.gz  # (still in fairseq/examples/emotion_conversion)
tar -xzvf data.tar.gz
```

Your `fairseq/examples/emotion_conversion` directory should like this:
```
drwxrwxr-x 3 felixkreuk felixkreuk   0 Feb  6  2022 data
drwxrwxr-x 3 felixkreuk felixkreuk   0 Sep 28 10:41 emotion_models
drwxr-xr-x 3 felixkreuk felixkreuk   0 Jun 29 05:43 fairseq_models
drwxr-xr-x 3 felixkreuk felixkreuk   0 Sep 28 10:41 preprocess
-rw-rw-r-- 1 felixkreuk felixkreuk 11K Dec  5 09:00 README.md
-rw-rw-r-- 1 felixkreuk felixkreuk  88 Mar  6  2022 requirements.txt
-rw-rw-r-- 1 felixkreuk felixkreuk 13K Jun 29 06:26 synthesize.py
```

Lastly, install fairseq and the other packages:
```
pip install --editable ./
pip install -r examples/emotion_conversion/requirements.txt
```

## Data preprocessing

### Convert your audio to discrete representations
Please follow the steps described [here](https://github.com/pytorch/fairseq/tree/main/examples/hubert/simple_kmeans).
To generate the same discrete representations please use the following:
1. [HuBERT checkpoint](https://dl.fbaipublicfiles.com/hubert/hubert_base_ls960.pt)
2. k-means model at `data/hubert_base_ls960_layer9_clusters200/data_hubert_base_ls960_layer9_clusters200.bin`

### Construct data splits
This step will use the discrete representations from the previous step and split them to train/valid/test sets for 3 tasks:
1. Translation model pre-training (BART language denoising)
2. Translation model training (content units emotion translation mechanism)
3. HiFiGAN model training (for synthesizing audio from discrete representations)

Your processed data should be at `data/`:
1. `hubert_base_ls960_layer9_clusters200` - discrete representations extracted using HuBERT layer 9, clustered into 200 clusters.
2. `data.tsv` - a tsv file pointing to the EmoV dataset in your environment (Please edit the first line of this file according to your path).

The following command will create the above splits:
```
python examples/emotion_conversion/preprocess/create_core_manifest.py \
    --tsv data/data.tsv \
    --emov-km data/hubert_base_ls960_layer9_clusters200/data.km \
    --km data/hubert_base_ls960_layer9_clusters200/vctk.km \
    --dict data/hubert_base_ls960_layer9_clusters200/dict.txt \
    --manifests-dir $DATA
```
* Set `$DATA` as the directory that will contain the processed data.

### Extract F0
To train the HiFiGAN vocoder we need to first extract the F0 curves:
```
python examples/emotion_conversion/preprocess/extract_f0.py \
    --tsv data/data.tsv \
    --extractor pyaapt \
```

## HiFiGAN training
Now we are all set to train the HiFiGAN vocoder:
```
python examples/emotion_conversion/speech-resynthesis/train.py 
    --checkpoint_path <hifigan-checkpoint-dir> \
    --config examples/emotion_conversion/speech-resynthesis/configs/EmoV/emov_hubert-layer9-cluster200_fixed-spkr-embedder_f0-raw_gst.json
```

## Translation Pre-training
Before translating emotions, we first need to pre-train the translation model as a denoising autoencoder (similarly to BART).
```
python train.py \
    $DATA/fairseq-data/emov_multilingual_denoising_cross-speaker_dedup_nonzeroshot/tokenized \
    --save-dir <your-save-dir> \
    --tensorboard-logdir <your-tb-dir> \
    --langs neutral,amused,angry,sleepy,disgusted,vctk.km \
    --dataset-impl mmap \
    --task multilingual_denoising \
    --arch transformer_small --criterion cross_entropy \
    --multilang-sampling-alpha 1.0 --sample-break-mode eos --max-tokens 16384 \
    --update-freq 1 --max-update 3000000 \
    --dropout 0.1 --attention-dropout 0.1 --relu-dropout 0.0 \
    --optimizer adam --weight-decay 0.01 --adam-eps 1e-06 \
    --clip-norm 0.1 --lr-scheduler polynomial_decay --lr 0.0003 \
    --total-num-update 3000000 --warmup-updates 10000 --fp16 \
    --poisson-lambda 3.5 --mask 0.3 --mask-length span-poisson --replace-length 1 --rotate 0 --mask-random 0.1 --insert 0 --permute-sentences 1.0 \
    --skip-invalid-size-inputs-valid-test \
    --user-dir examples/emotion_conversion/fairseq_models
```

## Translation Training
Now we are ready to train our emotion translation model:
```
python train.py \
    --distributed-world-size 1 \
    $DATA/fairseq-data/emov_multilingual_translation_cross-speaker_dedup/tokenized/ \
    --save-dir <your-save-dir> \
    --tensorboard-logdir <your-tb-dir> \
    --arch multilingual_small --task multilingual_translation \
    --criterion label_smoothed_cross_entropy --label-smoothing 0.2 \
    --lang-pairs neutral-amused,neutral-sleepy,neutral-disgusted,neutral-angry,amused-sleepy,amused-disgusted,amused-neutral,amused-angry,angry-amused,angry-sleepy,angry-disgusted,angry-neutral,disgusted-amused,disgusted-sleepy,disgusted-neutral,disgusted-angry,sleepy-amused,sleepy-neutral,sleepy-disgusted,sleepy-angry \
    --optimizer adam --adam-betas "(0.9, 0.98)" --adam-eps 1e-06 \
    --lr 1e-05 --clip-norm 0 --dropout 0.1 --attention-dropout 0.1 \
    --weight-decay 0.01 --warmup-updates 2000 --lr-scheduler inverse_sqrt \
    --max-tokens 4096 --update-freq 1 --max-update 100000 \
    --required-batch-size-multiple 8 --fp16 --num-workers 4 \
    --seed 2 --log-format json --log-interval 25 --save-interval-updates 1000 \
    --no-epoch-checkpoints --keep-best-checkpoints 1 --keep-interval-updates 1 \
    --finetune-from-model <path-to-model-from-previous-step> \
    --user-dir examples/emotion_conversion/fairseq_models
```
* To share encoders/decoders use the `--share-encoders` and `--share-decoders` flags.
* To add source/target emotion tokens use the `--encoder-langtok {'src'|'tgt'}` and `--decoder-langtok` flags.

## F0-predictor Training
The following command trains the F0 prediction module:
```
cd examples/emotion_conversion
python -m emotion_models.pitch_predictor n_tokens=200 \
    train_tsv="$DATA/denoising/emov/train.tsv" \
    train_km="$DATA/denoising/emov/train.km" \
    valid_tsv="$DATA/denoising/emov/valid.tsv" \
    valid_km="$DATA/denoising/emov/valid.km"
```
* See `hyra.run.dir` to configure directory for saving models.

## Duration-predictor Training
The following command trains the duration prediction modules:
```
cd examples/emotion_conversion
for emotion in "neutral" "amused" "angry" "disgusted" "sleepy"; do
    python -m emotion_models.duration_predictor n_tokens=200 substring=$emotion \
        train_tsv="$DATA/denoising/emov/train.tsv" \
        train_km="$DATA/denoising/emov/train.km" \
        valid_tsv="$DATA/denoising/emov/valid.tsv" \
        valid_km="$DATA/denoising/emov/valid.km"
done
```
* See `hyra.run.dir` to configure directory for saving models.
* After the above command you should have 5 duration models in your checkpoint directory:
```
❯ ll duration_predictor/
total 21M
-rw-rw-r-- 1 felixkreuk felixkreuk 4.1M Nov 15  2021 amused.ckpt
-rw-rw-r-- 1 felixkreuk felixkreuk 4.1M Nov 15  2021 angry.ckpt
-rw-rw-r-- 1 felixkreuk felixkreuk 4.1M Nov 15  2021 disgusted.ckpt
-rw-rw-r-- 1 felixkreuk felixkreuk 4.1M Nov 15  2021 neutral.ckpt
-rw-rw-r-- 1 felixkreuk felixkreuk 4.1M Nov 15  2021 sleepy.ckpt
```

## Token Generation
The following command uses `fairseq-generate` to generate the token sequences based on the source and target emotions.
```
fairseq-generate \
    $DATA/fairseq-data/emov_multilingual_translation_cross-speaker_dedup/tokenized/ \
    --task multilingual_translation \
    --gen-subset test \
    --path <your-saved-translation-checkpoint> \
    --beam 5 \
    --batch-size 4 --max-len-a 1.8 --max-len-b 10 --lenpen 1 --min-len 1 \
    --skip-invalid-size-inputs-valid-test --distributed-world-size 1 \
    --source-lang neutral --target-lang amused \
    --lang-pairs neutral-amused,neutral-sleepy,neutral-disgusted,neutral-angry,amused-sleepy,amused-disgusted,amused-neutral,amused-angry,angry-amused,angry-sleepy,angry-disgusted,angry-neutral,disgusted-amused,disgusted-sleepy,disgusted-neutral,disgusted-angry,sleepy-amused,sleepy-neutral,sleepy-disgusted,sleepy-angry \
    --results-path <token-output-path> \
    --user-dir examples/emotion_conversion/fairseq_models
```
* Modify `--source-lang` and `--target-lang` to control for the source and target emotions.
* See [fairseq documentation](https://fairseq.readthedocs.io/en/latest/command_line_tools.html#fairseq-generate) for a full overview of generation parameters (e.g., top-k/top-p sampling).

## Waveform Synthesis
Using the output of the above command, the HiFiGAN vocoder, and the prosody prediction modules (F0 and duration) we can now generate the output waveforms:
```
python examples/emotion_conversion/synthesize.py \
    --result-path <token-output-path>/generate-test.txt \
    --data $DATA/fairseq-data/emov_multilingual_translation_cross-speaker_dedup/neutral-amused \
    --orig-tsv examples/emotion_conversion/data/data.tsv \
    --orig-km examples/emotion_conversion/data/hubert_base_ls960_layer9_clusters200/data.km \
    --checkpoint-file <hifigan-checkpoint-dir>/g_00400000 \
    --dur-model duration_predictor/ \
    --f0-model pitch_predictor/pitch_predictor.ckpt \
    -s neutral -t amused \
    --outdir ~/tmp/emotion_results/wavs/neutral-amused
```
* Please make sure the source and target emotions here match those of the previous command.

# Citation
If you find this useful in your research, please use the following BibTeX entry for citation.
```
@article{kreuk2021textless,
  title={Textless speech emotion conversion using decomposed and discrete representations},
  author={Kreuk, Felix and Polyak, Adam and Copet, Jade and Kharitonov, Eugene and Nguyen, Tu-Anh and Rivi{\`e}re, Morgane and Hsu, Wei-Ning and Mohamed, Abdelrahman and Dupoux, Emmanuel and Adi, Yossi},
  journal={Conference on Empirical Methods in Natural Language Processing (EMNLP)},
  year={2022}
}
```