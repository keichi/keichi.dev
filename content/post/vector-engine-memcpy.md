---
title: Vector Engineでのmemcpyのベクトル化
date: 2023-06-14T18:03:30+09:00
description:
tags: []
draft: true
---

Vector Engine上で `std::memcpy` や `std::copy` を呼んだ際に，これらの関数があるコードではベクトル化されない現象が起きたので，調査しました．以下はnc++ 5.0.0で調査した結果です．

## TL;DR

コピー元とコピー先のアドレスが4バイトアラインされていれば，ベクトル化される．

```cpp
template <class T>
void do_memcpy(std::vector<T> &dst, const std::vector<T> &src)
{
    std::memcpy(dst.data() + offset, src.data(), n - offset);
}
```

```cpp
template <class T>
void do_copy_vector(std::vector<T> &dst, const std::vector<T> &src)
{
    std::copy(src.begin() + offset, src.end(), dst.begin());
}
```

```cpp
template <class T>
void do_copy_pointer(std::vector<T> &dst, const std::vector<T> &src)
{
    std::copy(src.data() + offset, src.data() + n, dst.data());
}
```
