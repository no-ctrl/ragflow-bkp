#!/usr/bin/env python3

# PEP 723 metadata
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "huggingface-hub",
#   "nltk",
#   "argparse",
# ]
# ///

from huggingface_hub import snapshot_download
from typing import Union
import nltk
import os
import urllib.request
import argparse

def get_urls(use_china_mirrors=False) -> Union[str, list[str]]:
    if use_china_mirrors:
        return [
            "http://mirrors.tuna.tsinghua.edu.cn/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb",
            "http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_arm64.deb",
            "https://repo.huaweicloud.com/repository/maven/org/apache/tika/tika-server-standard/3.0.0/tika-server-standard-3.0.0.jar",
            "https://repo.huaweicloud.com/repository/maven/org/apache/tika/tika-server-standard/3.0.0/tika-server-standard-3.0.0.jar.md5",
            "https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken",
            ["https://registry.npmmirror.com/-/binary/chrome-for-testing/121.0.6167.85/linux64/chrome-linux64.zip", "chrome-linux64-121-0-6167-85"],
            ["https://registry.npmmirror.com/-/binary/chrome-for-testing/121.0.6167.85/linux64/chromedriver-linux64.zip", "chromedriver-linux64-121-0-6167-85"],
        ]
    else:
        return [
            "http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb",
            "http://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_arm64.deb",
            "https://repo1.maven.org/maven2/org/apache/tika/tika-server-standard/3.0.0/tika-server-standard-3.0.0.jar",
            "https://repo1.maven.org/maven2/org/apache/tika/tika-server-standard/3.0.0/tika-server-standard-3.0.0.jar.md5",
            "https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken",
            ["https://storage.googleapis.com/chrome-for-testing-public/121.0.6167.85/linux64/chrome-linux64.zip", "chrome-linux64-121-0-6167-85"],
            ["https://storage.googleapis.com/chrome-for-testing-public/121.0.6167.85/linux64/chromedriver-linux64.zip", "chromedriver-linux64-121-0-6167-85"],
        ]

repos = [
    "InfiniFlow/text_concat_xgb_v1.0",
    "InfiniFlow/deepdoc",
    "InfiniFlow/huqie",
    "BAAI/bge-large-zh-v1.5",
    "maidalun1020/bce-embedding-base_v1",
]

def download_model(repo_id, model_dir):
    local_dir = os.path.abspath(os.path.join(model_dir, repo_id))
    os.makedirs(local_dir, exist_ok=True)
    snapshot_download(repo_id=repo_id, local_dir=local_dir)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Download dependencies with optional China mirror support')
    parser.add_argument('--china-mirrors', action='store_true', help='Use China-accessible mirrors for downloads')
    parser.add_argument('--model-dir', default='huggingface.co', help='Directory to download HuggingFace models')
    parser.add_argument('--nltk-dir', default='nltk_data', help='Directory to download NLTK data')
    parser.add_argument('--deps-dir', default='.', help='Directory to download other dependencies')
    args = parser.parse_args()
    
    # Create directories if they don't exist
    os.makedirs(args.model_dir, exist_ok=True)
    os.makedirs(args.nltk_dir, exist_ok=True)
    os.makedirs(args.deps_dir, exist_ok=True)

    urls = get_urls(args.china_mirrors)
    
    for url in urls:
        download_url = url[0] if isinstance(url, list) else url
        filename = url[1] if isinstance(url, list) else url.split("/")[-1]
        filepath = os.path.join(args.deps_dir, filename)
        print(f"Downloading {filename} from {download_url} to {filepath}...")
        if not os.path.exists(filepath):
            urllib.request.urlretrieve(download_url, filepath)

    print(f"Downloading NLTK data to {args.nltk_dir}...")
    local_nltk_dir = os.path.abspath(args.nltk_dir)
    for data in ['wordnet', 'punkt', 'punkt_tab']:
        print(f"Downloading nltk {data}...")
        nltk.download(data, download_dir=local_nltk_dir)

    print(f"Downloading HuggingFace models to {args.model_dir}...")
    for repo_id in repos:
        print(f"Downloading huggingface repo {repo_id}...")
        download_model(repo_id, args.model_dir)
