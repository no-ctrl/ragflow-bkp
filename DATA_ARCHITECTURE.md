# RAGFlow Data Architecture

## Overview

RAGFlow uses a **dual-database architecture** where MySQL and Elasticsearch serve complementary roles:

- **MySQL**: Relational database for metadata, configuration, and user data
- **Elasticsearch**: Vector and text search engine for document chunks and embeddings

## Data Distribution

### MySQL (Relational Database)

MySQL serves as the **control plane**, storing all metadata and relational data.

#### User & Tenant Management
| Table | Purpose | Key Fields |
|-------|---------|------------|
| `user` | User accounts and authentication | `id`, `email`, `password`, `nickname`, `access_token` |
| `tenant` | Organization/workspace data | `id`, `name`, `llm_id`, `embd_id`, `credit` |
| `user_tenant` | User-tenant relationships | `user_id`, `tenant_id`, `role` |
| `api_token` | API authentication tokens | `tenant_id`, `token`, `dialog_id` |

#### Knowledge Base Metadata
| Table | Purpose | Key Fields |
|-------|---------|------------|
| `knowledgebase` | KB configuration and statistics | `id`, `tenant_id`, `name`, `embd_id`, `doc_num`, `chunk_num`, `token_num` |
| `document` | Document metadata and status | `id`, `kb_id`, `name`, `location`, `size`, `chunk_num`, `progress`, `process_duration` |
| `file` | File system structure | `id`, `parent_id`, `tenant_id`, `name`, `location`, `type` |
| `file2document` | File-to-document mappings | `file_id`, `document_id` |

#### Processing & Tasks
| Table | Purpose | Key Fields |
|-------|---------|------------|
| `task` | Document processing tasks | `id`, `doc_id`, `progress`, `chunk_ids`, `task_type`, `retry_count` |

#### LLM Configuration
| Table | Purpose | Key Fields |
|-------|---------|------------|
| `llm_factories` | LLM provider information | `name`, `tags`, `logo` |
| `llm` | Available LLM models | `llm_name`, `model_type`, `fid`, `max_tokens` |
| `tenant_llm` | Tenant-specific LLM configs | `tenant_id`, `llm_factory`, `llm_name`, `api_key`, `api_base` |

#### Chat & Conversations
| Table | Purpose | Key Fields |
|-------|---------|------------|
| `dialog` | Chat application configuration | `id`, `tenant_id`, `name`, `llm_id`, `kb_ids`, `prompt_config`, `llm_setting` |
| `conversation` | Chat conversation history | `id`, `dialog_id`, `name`, `message`, `reference`, `user_id` |
| `api_4_conversation` | API conversation logs | `id`, `dialog_id`, `user_id`, `message`, `tokens`, `duration` |

#### Canvas & Workflows
| Table | Purpose | Key Fields |
|-------|---------|------------|
| `user_canvas` | User workflow canvases | `id`, `user_id`, `title`, `canvas_type`, `dsl` |
| `canvas_template` | Canvas templates | `id`, `title`, `canvas_type`, `dsl` |

#### Search Applications
| Table | Purpose | Key Fields |
|-------|---------|------------|
| `search` | Search application configs | `id`, `tenant_id`, `name`, `search_config` |

### Elasticsearch (Vector + Text Search)

Elasticsearch serves as the **data plane**, storing chunked content with embeddings for retrieval.

#### Index Structure

Each tenant has its own index with the naming pattern based on `tenant_id`. All chunks within a tenant's knowledge bases are stored in a single index, distinguished by `kb_id`.

#### Chunk Document Schema

**Core Fields:**
- `id` (keyword): Unique chunk identifier
- `kb_id` (keyword): Knowledge base identifier (links to MySQL `knowledgebase.id`)
- `doc_id` (keyword): Document identifier (links to MySQL `document.id`)

**Content Fields:**
- `content_with_weight` (text): Chunk text content
- `*_tks` (text): Tokenized text fields for full-text search
- `*_ltks` (text): Long tokenized text fields

**Vector Embeddings:**
- `q_{dimension}_vec` (dense_vector): Query embeddings
  - Supported dimensions: 512, 768, 1024, 1536
  - Similarity: cosine
  - Example: `q_1536_vec` for OpenAI embeddings

**Metadata Fields:**
- `available_int` (integer): Availability status
- `create_time` (date): Creation timestamp
- `create_timestamp_flt` (float): Unix timestamp
- Custom metadata fields from documents

**Ranking Features:**
- `*_fea` (rank_feature): Single ranking feature
- `*_feas` (rank_features): Multiple ranking features
- Used for hybrid search and reranking

#### Dynamic Field Mapping

Elasticsearch uses dynamic templates (defined in `conf/mapping.json`) to automatically map fields based on suffixes:

| Suffix | Type | Purpose |
|--------|------|---------|
| `*_vec` | dense_vector | Vector embeddings (512/768/1024/1536 dims) |
| `*_tks` | text | Tokenized text with custom similarity |
| `*_ltks` | text | Long tokenized text |
| `*_kwd`, `*_id` | keyword | Exact match fields |
| `*_int` | integer | Integer values |
| `*_flt` | float | Floating point numbers |
| `*_dt`, `*_time` | date | Timestamps |
| `*_fea` | rank_feature | Ranking signals |
| `*_feas` | rank_features | Multiple ranking signals |

## Data Flow

### 1. Document Ingestion

```
User uploads document
    ↓
MySQL: Create Document record (metadata)
    ↓
Task: Parse document → Create chunks
    ↓
Task: Generate embeddings for chunks
    ↓
Elasticsearch: Insert chunks with vectors
    ↓
MySQL: Update Document (chunk_num, token_num, progress)
```

**Code References:**
- Document creation: `api/db/db_models.py:662` (Document model)
- Chunk insertion: `rag/svr/task_executor.py:628`
- Task management: `api/db/db_models.py:714` (Task model)

### 2. Search & Retrieval

```
User submits query
    ↓
MySQL: Fetch Dialog configuration (kb_ids, llm_setting)
    ↓
Elasticsearch: Vector + text search
    │ - Filter by kb_id
    │ - Vector similarity search
    │ - Full-text search
    │ - Hybrid fusion
    ↓
Elasticsearch: Return ranked chunks
    ↓
MySQL: Fetch Document metadata
    ↓
LLM: Generate response with context
    ↓
MySQL: Save Conversation (message, references)
```

**Code References:**
- Search execution: `rag/utils/es_conn.py:141` (search method)
- Dialog config: `api/db/db_models.py:732` (Dialog model)
- Conversation storage: `api/db/db_models.py:767` (Conversation model)

### 3. Knowledge Base Operations

```
Create Knowledge Base
    ↓
MySQL: Insert Knowledgebase record
    ↓
Elasticsearch: Create index (if new tenant)

Delete Knowledge Base
    ↓
MySQL: Mark Knowledgebase as deleted (status='0')
    ↓
Elasticsearch: Delete chunks (filter by kb_id)
    ↓
MySQL: Update Knowledgebase (doc_num=0, chunk_num=0)
```

**Code References:**
- KB model: `api/db/db_models.py:634` (Knowledgebase model)
- Index creation: `rag/utils/es_conn.py:100` (createIdx method)
- Chunk deletion: `rag/utils/es_conn.py:420` (delete method)

## Search Capabilities

### Hybrid Search

RAGFlow combines multiple search methods:

1. **Vector Similarity Search**
   - Dense vector embeddings (cosine similarity)
   - Configurable via `vector_similarity_weight`

2. **Full-Text Search**
   - BM25-based text matching
   - Custom scripted similarity
   - Multi-field query strings

3. **Weighted Fusion**
   - Combines vector and text scores
   - Weighted sum or other fusion methods
   - Configurable weights per knowledge base

4. **Reranking**
   - Optional reranking with specialized models
   - Configurable via `rerank_id` in Dialog/Search configs

**Code References:**
- Search implementation: `rag/utils/es_conn.py:141-289`
- Fusion logic: `rag/utils/es_conn.py:186-190`

## Relationships & Keys

### Primary Relationships

```
tenant (MySQL)
    ├── knowledgebase (MySQL)
    │   ├── document (MySQL)
    │   │   └── chunks (Elasticsearch: filtered by kb_id + doc_id)
    │   └── chunks (Elasticsearch: filtered by kb_id)
    ├── dialog (MySQL)
    │   ├── kb_ids → knowledgebase (many-to-many)
    │   └── conversation (MySQL)
    └── user_tenant (MySQL)
        └── user (MySQL)
```

### Key Linking Fields

| MySQL Table | Elasticsearch Field | Purpose |
|-------------|---------------------|---------|
| `tenant.id` | Index name (derived) | Tenant isolation |
| `knowledgebase.id` | `kb_id` | Knowledge base filtering |
| `document.id` | `doc_id` | Document tracing |
| N/A | `id` (chunk) | Individual chunk identifier |

## Configuration Files

### Service Configuration
**File:** `conf/service_conf.yaml`

```yaml
mysql:
  name: 'rag_flow'
  host: '127.0.0.1'
  port: 5455
  user: 'root'
  password: 'infini_rag_flow'

es:
  hosts: 'http://127.0.0.1:1200'
  username: 'elastic'
  password: 'infini_rag_flow'
```

### Elasticsearch Mapping
**File:** `conf/mapping.json`

Defines:
- Index settings (shards, replicas, refresh interval)
- Dynamic field templates
- Vector dimensions and similarity functions
- Custom similarity algorithms

## Storage Backends

### Object Storage (MinIO/S3)

Binary files and images are stored separately:

- **Original Documents**: PDF, DOCX, images, etc.
- **Extracted Images**: Images from document parsing
- **User Avatars**: Base64 or object storage

**Configuration:**
- MinIO: `conf/service_conf.yaml` (minio section)
- Location stored in MySQL: `document.location`, `file.location`

**Code References:**
- Storage interface: MinIO client integration
- Chunk images: `rag/svr/task_executor.py:620-624` (delete_image)

### Cache Layer (Redis)

Redis provides caching and temporary storage:

- Session management
- Task queues
- Temporary embeddings cache
- Rate limiting

**Configuration:** `conf/service_conf.yaml` (redis section)

## Scalability Considerations

### Multi-Tenant Isolation

- **Index Level**: Each tenant has separate Elasticsearch index
- **Row Level**: `kb_id` filtering within shared index
- **Benefits**: Balance between isolation and resource efficiency

### Sharding Strategy

**Elasticsearch:**
- 2 shards per index (default, see `conf/mapping.json:4`)
- 0 replicas (for development; increase for production)
- Automatic distribution across cluster nodes

**MySQL:**
- Connection pooling (max 900 connections)
- Retry logic for connection failures
- Distributed locks for critical operations

### Performance Optimizations

1. **Bulk Operations**
   - Chunk insertion in batches of `DOC_BULK_SIZE`
   - Elasticsearch bulk API for efficiency

2. **Vector Search**
   - Approximate nearest neighbor (ANN) search
   - Cosine similarity for all vector fields
   - Configurable `top_k` for retrieval scope

3. **Refresh Interval**
   - 1000ms refresh for near real-time search
   - Balances visibility vs. indexing performance

## Data Lifecycle

### Document Processing States

MySQL `document.run` field controls processing:
- `'0'`: Idle/stopped
- `'1'`: Running/processing
- `'2'`: Canceled

MySQL `document.status` field indicates validity:
- `'0'`: Deleted/wasted
- `'1'`: Valid/active

### Chunk Management

**Creation:**
1. Document parsed into chunks
2. Embeddings generated
3. Bulk inserted into Elasticsearch
4. Chunk IDs stored in MySQL `task.chunk_ids`

**Deletion:**
1. Delete from Elasticsearch (by chunk IDs)
2. Delete associated images from object storage
3. Update MySQL statistics

**Code References:**
- Chunk insertion: `rag/svr/task_executor.py:627-638`
- Chunk deletion: `rag/svr/task_executor.py:645-649`

## Summary

| Aspect | MySQL | Elasticsearch |
|--------|-------|---------------|
| **Role** | Control Plane | Data Plane |
| **Data Type** | Metadata, Configuration | Content, Embeddings |
| **Structure** | Relational tables | Document index |
| **Query Type** | CRUD, joins, transactions | Vector search, full-text |
| **Scalability** | Vertical (pooling, sharding) | Horizontal (cluster) |
| **Consistency** | Strong (ACID) | Eventual (near real-time) |
| **Size** | Small (metadata only) | Large (all content) |
| **Examples** | Users, KBs, Documents | Chunks, Vectors, Text |

This architecture enables RAGFlow to efficiently manage user data and metadata in MySQL while leveraging Elasticsearch's powerful vector and text search capabilities for semantic retrieval.
