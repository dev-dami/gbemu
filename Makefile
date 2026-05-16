ZIG = zig
BUILD_DIR = zig-out

gameboy:
	$(ZIG) build -Doptimize=ReleaseFast

clean:
	rm -rf $(BUILD_DIR)

run: gameboy
	$(BUILD_DIR)/bin/gameboy

.PHONY: clean run
