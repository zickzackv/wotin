# wotin Tools

Utility scripts and tools for wotin development and testing.

## Test Data Generator

Generates random time tracking frames for testing purposes.

### Building

**Linux/macOS:**
```bash
cd tools
./build_generator.sh
```

**Windows:**
```cmd
cd tools
build_generator.bat
```

**Manual build:**
```bash
odin build tools/generate_test_data.odin -file -out:tools/build/generate_test_data
```

### Running

```bash
# After building
./tools/build/generate_test_data

# On Windows
.\tools\build\generate_test_data.exe
```

This will create a `test_frames.json` file in your current directory with 100 randomly generated time tracking frames.

### Generated Data

The generator creates frames with:
- **Random projects** from a predefined list (wotin, website-redesign, mobile-app, etc.)
- **Random timestamps** within the last 30 days
- **Random durations** between 15 minutes and 8 hours
- **Random tags** (0-3 tags per frame) from categories like coding, meeting, debugging, etc.
- **Unique IDs** in the format `frame_00001`, `frame_00002`, etc.

### Example Output

```json
[
  {
    "id": "frame_00001",
    "project": "wotin",
    "started_at": "2025-11-25T14:30:00Z",
    "stopped_at": "2025-11-25T16:45:00Z",
    "tags": ["coding", "debugging"]
  },
  {
    "id": "frame_00002",
    "project": "website-redesign",
    "started_at": "2025-11-24T09:15:00Z",
    "stopped_at": "2025-11-24T11:30:00Z",
    "tags": ["design", "planning"]
  }
]
```

### Using the Test Data

You can use the generated `test_frames.json` file to:
- Test JSON parsing functionality
- Validate report generation
- Test filtering and search features
- Benchmark performance with realistic data
- Develop UI components

### Customization

You can modify the generator to:
- Change the number of frames (modify the loop in `main`)
- Add more projects or tags (edit the `PROJECTS` and `TAGS` arrays)
- Adjust time ranges (modify the random offset calculations)
- Change duration ranges (adjust `duration_minutes` calculation)
