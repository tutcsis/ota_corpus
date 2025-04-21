/*
    Writer and reader of MinHash files.

Copyright (c) 2023-2025, Naoaki Okazaki

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#pragma once

/*

A MinHash file (.mh) stores $R$ bucket arrays each of which consists of $N$
buckets, where $N$ presents the number of items and $R$ presents the number
of buckets (end-start). The table below shows the layout of a file, where
a cell (i,j) corresponds to a bucket #j of an item #i. We call this layout
"bucket major."

 ============ Bucket #0 ============ === Bucket #1 === .. == Bucket #R =
+--------+--------+--------+--------+--------+--------+--------+--------+
| (0, 0) | (1, 0) | ...... | (N, 0) | (0, 1) | (1, 1) | ...... | (N, R) | 
+--------+--------+--------+--------+--------+--------+--------+--------+

It is more straightforward to implement a code for writing hash buckets in
"item major" shown below because we can just process an item coming from
the stream one by one.

 ============= Item #1 ============= ==== Item #1 ====  ... == Item #N =
+--------+--------+--------+--------+--------+--------+--------+--------+
| (0, 0) | (0, 1) | ...... | (0, B) | (1, 0) | (1, 1) | ...... | (N, R) | 
+--------+--------+--------+--------+--------+--------+--------+--------+

However, this item-major layout causes a serious I/O bottleneck when a
deduplication program (doubri-dedup) builds a bucket array. The program
must read (0, 0), (1, 0), (2, 0), ..., (N, 0) for the bucket array #0, but
the read pattern is too fragmented: e.g., read 80 bytes for the item #0,
seek 3120 bytes to skip 39 buckets, read 80 bytes for the item #1, ...,
when each bucket is 80 byte long and $R$ = 40. Because the size of SSD sector
is usually 512 bytes, the program must read 6.4 times larger data to obtain
a bucket of 80 bytes long.

Therefore, we should use the bucket-major layout. However, it is difficult to
find the number of items from a stream especially when the input stream is
gzipped. For this reason, a MinHash file uses the bucket-major layout for
every 512 items. MinHashWriter class maintains a buffer to store buckets of
512 items at most, and flushes the buffer to the file when it is full.
MinHashReader class can read a bucket array at a time (read_bucket_array).

Our experiment demonstrated that reading a bucket array in bucket-major
layout was 20 times faster than that in item-major layout on parallel reading
with 64CPUs and SSD.

*/

#include <bit>
#include <byteswap.h>
#include <cstdint>
#include <fstream>
#include <sstream>
#include <stdexcept>
#include <vector>

const int minhash_sector_size = 512;

/**
 * A writer for MinHash files (*.mh)
 */
template <class HashType>
class MinHashWriter
{
protected:
    size_t m_num_items{0};
    size_t m_bytes_per_hash{0};
    size_t m_num_hash_values{0};
    size_t m_begin{0};
    size_t m_end{0};

    std::ofstream m_ofs;
    std::vector< std::vector<HashType> > m_bas;
    size_t m_i{0};

public:
    /**
     * Construct.
     */
    MinHashWriter()
    {
    }

    /**
     * Destruct.
     */
    virtual ~MinHashWriter()
    {
        if (m_ofs.is_open()) {
            close();
        }
    }

    /**
     * Open a MinHash file for writing.
     *  @param  filename        The name for the MinHash file.
     *  @param  num_hash_values The number of MinHash values per bucket.
     *  @param  begin           The beginning number of bucket arrays.
     *  @param  end             The end number of bucket arrays.
     */
    void open(const std::string& filename, size_t num_hash_values, size_t begin, size_t end)
    {
        // Open a MinHash file.
        m_ofs.open(filename, std::ios_base::out | std::ios::binary);
        if (m_ofs.fail()) {
            throw std::invalid_argument(
                std::string("Failed to open: ") + filename
            );
        }

        // 0x0000: Write the header: "DoubriH4"
        m_ofs.write("DoubriH4", 8);
        // 0x0008: Reserve the slot to write the number of items.
        writeval<uint64_t>(m_ofs, 0);
        // 0x0010: Write the number of bytes per hash.
        writeval<uint16_t>(m_ofs, sizeof(HashType));
        // 0x0012: Write the number of hash values per bucket.
        writeval<uint16_t>(m_ofs, num_hash_values);
        // 0x0014: Write the begin index of buckets.
        writeval<uint32_t>(m_ofs, begin);
        // 0x0018: Write the end index of buckets.
        writeval<uint32_t>(m_ofs, end);
        // 0x001C: Write the sector size.
        writeval<uint32_t>(m_ofs, minhash_sector_size);
        if (m_ofs.fail()) {
            throw std::runtime_error(
                std::string("Failed to write a header: ") + filename
            );
        }
        // 0x0020: The bucket arrays start at this address.

        // Allocate bucket arrays [begin, end).
        m_bas.resize(end - begin);
        for (auto& ba : m_bas) {
            // Resize and initialize each bucket buffer with zero.
            ba.resize(minhash_sector_size * num_hash_values, 0);
        }
        m_i = 0;

        // Store the parameters in this object.
        m_num_items = 0;
        m_bytes_per_hash = sizeof(HashType);
        m_num_hash_values = num_hash_values;
        m_begin = begin;
        m_end = end;
    }

    /**
     * Close the MinHash file.
     */
    void close()
    {
        // Flush the remaining buckets.
        flush();

        // Store the number of items in the header.
        m_ofs.seekp(8);
        writeval<uint64_t>(m_ofs, m_num_items);
        if (m_ofs.fail()) {
            throw std::runtime_error(
                std::string("Failed to write data to the file")
            );
        }

        // Close the file.
        m_ofs.close();
    }

    /**
     * Write a MinHash bucket.
     *  @param  ptr     The pointer to the MinHash bucket.
     */
    void put(const HashType *ptr)
    {
        // Flush the bucket buffers to the file if they are full.
        if (minhash_sector_size <= m_i) {
            flush();
        }

        // Write the hash values to the bucket buffers.
        for (size_t j = m_begin; j < m_end; ++j) {
            auto& ba = m_bas[j-m_begin];
            const size_t offset = m_i * m_num_hash_values;
            for (size_t i = 0; i < m_num_hash_values; ++i) {
                // We store MinHash values in big endian so that we can easily
                // check byte streams with a binary editor (for debugging).
                if constexpr (std::endian::native == std::endian::little) {
                    // Use std::byteswap when C++23 is supported by most compilers.
                    // ba[offset+i] = std::byteswap((*ptr++));
                    if constexpr (sizeof(HashType) == 8) {
                        ba[offset+i] = bswap_64(*ptr++);
                    } else if constexpr (sizeof(HashType) == 4) {
                        ba[offset+i] = bswap_32(*ptr++);
                    } else {
                        ba[offset+i] = *ptr++;
                    }
                } else {
                    ba[offset+i] = *ptr++;
                }
            }
        }

        ++m_i;
        ++m_num_items;
    }

protected:
    /**
     * Flush the buffer to the file.
     */
    void flush()
    {
        if (0 < m_i) {
            // Write the bucket arrays to the file.
            for (size_t j = m_begin; j < m_end; ++j) {
                auto& ba = m_bas[j-m_begin];
                m_ofs.write(
                    reinterpret_cast<const char*>(&ba.front()),
                    m_i * sizeof(HashType) * m_num_hash_values
                    );
                if (m_ofs.fail()) {
                    throw std::runtime_error(
                        std::string("Failed to write data to the file")
                    );
                }
            }
        }
        m_i = 0;
    }

public:
    /**
     * Get the number of items.
     *  @return The number of items in the file.
     */
    inline size_t num_items() const
    {
        return m_num_items;
    }

protected:
    template <typename StreamT, typename ValueT>
    inline void writeval(std::ostream& os, ValueT value)
    {
        StreamT value_ = static_cast<StreamT>(value);
        os.write(reinterpret_cast<char*>(&value_), sizeof(value_));
    }
};



/**
 * A reader for a MinHash file.
 */
class MinHashReader
{
public:
    size_t m_num_items{0};
    size_t m_bytes_per_hash{0};
    size_t m_num_hash_values{0};
    size_t m_begin{0};
    size_t m_end{0};

public:
    std::ifstream m_ifs;
    size_t m_i{0};

public:
    /**
     * Construct.
     */
    MinHashReader()
    {
    }

    /**
     * Destruct.
     */
    virtual ~MinHashReader()
    {
    }

    /**
     * Open a MinHash file for reading.
     *  @param  filename        The name for the MinHash file.
     */
    void open(const std::string& filename)
    {
        // Open a MinHash file.
        m_ifs.open(filename, std::ios_base::in | std::ios::binary);
        if (m_ifs.fail()) {
            throw std::invalid_argument(
                std::string("Failed to open: ") + filename
            );
        }

        // Check the header.
        char magic[9]{};
        m_ifs.read(magic, 8);
        if (std::strcmp(magic, "DoubriH4") != 0) {
            throw std::runtime_error(
                std::string("Invalid magic '") + magic + std::string("' in the file: ") + filename
            );
        }

        // Read the parameters in the hash file.
        m_num_items = readval<uint64_t, size_t>(m_ifs);
        m_bytes_per_hash = readval<uint16_t, size_t>(m_ifs);
        m_num_hash_values = readval<uint16_t, size_t>(m_ifs);
        m_begin = readval<uint32_t, size_t>(m_ifs);
        m_end = readval<uint32_t, size_t>(m_ifs);
        size_t sector_size = readval<uint32_t, size_t>(m_ifs);
        if (sector_size != minhash_sector_size) {
            throw std::runtime_error(
                std::string("Invalid sector size in the file: ") + filename
            );
        }
        if (m_ifs.eof()) {
            throw std::runtime_error(
                std::string("EOF when reading the header of the file: ") + filename
            );
        }
        if (m_ifs.fail()) {
            throw std::invalid_argument(
                std::string("Failed to read the header from the file: ") + filename
            );
        }
    }

    /**
     * Read a bucket array at a time.
     *  @param  buffer          The buffer to store the bucket array.
     *  @param  bucket_number   The number of the bucket array to read.
     */
    void read_bucket_array(uint8_t *buffer, size_t bucket_number)
    {
        uint8_t *p = buffer;
        const size_t num_sectors = m_num_items / minhash_sector_size;
        const size_t num_remaining = m_num_items % minhash_sector_size;
        const size_t bytes_per_sector_ba = minhash_sector_size * m_bytes_per_hash * m_num_hash_values;
        const size_t bytes_per_sector = (m_end - m_begin) * bytes_per_sector_ba;

        for (size_t sector = 0; sector < num_sectors; ++sector) {
            const size_t offset = 32 + bytes_per_sector * sector + bytes_per_sector_ba * (bucket_number - m_begin);
            m_ifs.seekg(offset);
            if (m_ifs.fail()) {
                throw std::runtime_error(
                    std::string("Failed to seek data in the file")
                );
            }
            m_ifs.read(reinterpret_cast<char*>(p), bytes_per_sector_ba);
            if (m_ifs.eof()) {
                throw std::runtime_error(
                    std::string("EOF when reading the buckets from the file")
                );
            }
            if (m_ifs.fail()) {
                throw std::runtime_error(
                    std::string("Failed to read buckets from the file")
                );
            }
            p += bytes_per_sector_ba;
        }
        if (0 < num_remaining) {
            size_t bytes = num_remaining * m_bytes_per_hash * m_num_hash_values;
            const size_t offset = 32 + bytes_per_sector * num_sectors + bytes * (bucket_number - m_begin);
            m_ifs.seekg(offset);
            if (m_ifs.fail()) {
                throw std::runtime_error(
                    std::string("Failed to seek data in the file")
                );
            }
            m_ifs.read(reinterpret_cast<char*>(p), bytes);
            if (m_ifs.eof()) {
                throw std::runtime_error(
                    std::string("EOF when reading the buckets from the file")
                );
            }
            if (m_ifs.fail()) {
                throw std::runtime_error(
                    std::string("Failed to read buckets from the file")
                );
            }
            p += bytes;
        }
    }

protected:
    template <typename StreamT, typename ValueT>
    inline ValueT readval(std::istream& is)
    {
        StreamT value_;
        is.read(reinterpret_cast<char*>(&value_), sizeof(value_));
        return static_cast<ValueT>(value_);
    }
};
