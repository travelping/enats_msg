# News

* **Version 1.0.0** (*2025-03-24*):
    * Fix header parsing.
	* Released as first stable version of this fork.

* **Version 0.9.0** (*2024-07-30*):
    * This version is incompatible with the original nats_msg versions of the library.
	* The decoder has been reorganized to use continuation passing to better reuse binary
	match contexts, resulting in a 50% performance increase.
	* Multi message decoding has be reorganized to use continuation passing, resulting in
	better performace for large message chunks.

* **Version 0.4.1** (*2016-03-23*):
    * This version is incompatible with previous versions of the library.
    * Decoding is lazy, in the sense that, only a single message is decoded whenever
    the decode is called. You can use `nats_msg:decode_all/1` to simulate the old behaviour.
    * HUGE performance improvements (2x - 100x).
    * The parser is much more stricter now.
    * Encoding functions return iodata instead of binary.
    * You can use iodata anywhere a binary is expected.
