find . -type f \( -name "*.c" -o -name "*.h" -o -name "*.cpp" -o -name "*.hpp" \) \
  -exec sha256sum {} \; > code_hashes.sha256