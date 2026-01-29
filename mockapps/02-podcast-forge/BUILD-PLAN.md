# Podcast Forge - Build Plan

## Phase Overview

| Phase | Deliverable | Effort | Dependencies |
|-------|-------------|--------|--------------|
| Phase 1 | MVP CLI - Normalize and assemble | 4 days | simple_audio, simple_json |
| Phase 2 | Full CLI - Projects, manifests, build | 5 days | Phase 1, simple_hash, simple_file |
| Phase 3 | Polish - Publishing, templates, documentation | 3 days | Phase 2 |

---

## Phase 1: MVP

### Objective

Demonstrate core value: take a raw recording, normalize loudness, add intro/outro, output final episode.

### Deliverables

1. **FORGE_CLI** - Basic command-line interface with normalize and assemble commands
2. **FORGE_NORMALIZER** - Loudness measurement and normalization
3. **FORGE_ASSEMBLER** - Audio concatenation with crossfade support
4. **FORGE_FADER** - Fade in/out effects
5. **FORGE_TRIMMER** - Silence trimming

### Tasks

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| T1.1 | Create project structure and ECF | Compiles with all dependencies |
| T1.2 | Implement FORGE_NORMALIZER | Measure LUFS, apply gain |
| T1.3 | Implement FORGE_ASSEMBLER | Concatenate multiple WAV files |
| T1.4 | Implement FORGE_FADER | Apply fade in/out to buffer |
| T1.5 | Implement FORGE_TRIMMER | Detect and trim silence |
| T1.6 | Implement FORGE_CLI (normalize) | CLI command for normalization |
| T1.7 | Implement FORGE_CLI (assemble) | CLI command for assembly |
| T1.8 | Write MVP tests | Test each component |

### Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| test_normalize_quiet | -30 LUFS audio | -16 LUFS output |
| test_normalize_loud | -10 LUFS audio | -16 LUFS output |
| test_assemble_two | Two buffers | Single combined buffer |
| test_fade_in | Buffer + 500ms | First 500ms fades 0->1 |
| test_fade_out | Buffer + 1000ms | Last 1000ms fades 1->0 |
| test_trim_start | Audio with 2s silence | Silence trimmed to 100ms |
| test_trim_end | Audio with 3s silence | Silence trimmed to 500ms |
| test_cli_normalize | "normalize raw.wav -t -16" | Normalized file created |
| test_cli_assemble | "assemble --intro i.wav main.wav --outro o.wav" | Assembled file |

### Exit Criteria

- `podcast-forge normalize raw.wav --target -16` produces correctly normalized audio
- `podcast-forge assemble --intro intro.wav main.wav --outro outro.wav` produces assembled episode
- Output matches expected loudness within 0.5 LUFS

---

## Phase 2: Full Implementation

### Objective

Production-ready CLI with project management, episode manifests, and build pipeline.

### Deliverables

1. **FORGE_PROJECT** - Project/show definition
2. **FORGE_EPISODE** - Episode container
3. **FORGE_MANIFEST** - Episode manifest handling
4. **FORGE_BUILDER** - Full build pipeline
5. **Build commands** - new, init, episode, build, status

### Tasks

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| T2.1 | Implement FORGE_PROJECT | Load/save project config |
| T2.2 | Implement FORGE_MANIFEST | Parse episode manifests |
| T2.3 | Implement FORGE_EPISODE | Episode state management |
| T2.4 | Implement FORGE_BUILDER | Full build pipeline |
| T2.5 | Add 'new' command | Create new project |
| T2.6 | Add 'init' command | Initialize in current dir |
| T2.7 | Add 'episode' command | Create new episode |
| T2.8 | Add 'build' command | Build from manifest |
| T2.9 | Add 'status' command | Show project status |
| T2.10 | Implement build caching | Skip unchanged episodes |
| T2.11 | Write integration tests | End-to-end workflow |

### Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| test_project_load | forge.json | Project object with settings |
| test_project_create | "new MyPodcast" | Directory structure created |
| test_manifest_load | manifest.json | Manifest with segments |
| test_manifest_validate | Invalid manifest | Validation errors reported |
| test_episode_create | "episode Ep1" | Episode directory + manifest |
| test_build_single | Episode manifest | Built episode file |
| test_build_all | Project with 3 episodes | 3 built episodes |
| test_build_cache | Unchanged episode | Skipped (cached) |
| test_status | Project directory | Status summary |

### Exit Criteria

- Can create new project with `podcast-forge new`
- Can create episodes with `podcast-forge episode`
- Can build episodes with `podcast-forge build`
- Build caching works (unchanged episodes skip)
- Status shows correct project state

---

## Phase 3: Production Polish

### Objective

Publication features, templates, and documentation.

### Deliverables

1. **FORGE_PUBLISHER** - Final output generation
2. **FORGE_METADATA** - ID3/metadata handling
3. **Show notes templates** - Automated documentation
4. **RSS feed generation** - Podcast distribution
5. **Documentation** - README, examples

### Tasks

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| T3.1 | Implement FORGE_PUBLISHER | Export to multiple formats |
| T3.2 | Implement FORGE_METADATA | ID3 tag embedding |
| T3.3 | Add 'publish' command | Generate final outputs |
| T3.4 | Implement show notes generation | Template-based docs |
| T3.5 | Implement RSS feed generation | Valid podcast RSS |
| T3.6 | Add project templates | interview, solo, panel |
| T3.7 | Write README.md | Installation, usage, examples |
| T3.8 | Create example project | Full sample podcast |
| T3.9 | Performance optimization | Parallel segment processing |
| T3.10 | Final test suite | Full coverage |

### Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| test_publish_wav | Built episode | WAV file in output |
| test_publish_mp3 | Built episode | MP3 file with correct bitrate |
| test_metadata | Episode + metadata | ID3 tags embedded |
| test_show_notes | Episode + template | Generated markdown |
| test_rss_generate | Project | Valid RSS XML |
| test_template_interview | "new --template interview" | Interview-style project |
| test_performance | 1-hour episode | Builds in <12 minutes |

### Exit Criteria

- Publish command generates WAV and/or MP3
- Metadata is correctly embedded
- RSS feed is valid
- Documentation complete
- Example project included

---

## ECF Target Structure

```xml
<!-- Library target (reusable processing engine) -->
<target name="forge_lib">
    <root all_classes="true" />
    <library name="simple_audio" location="..."/>
    <library name="simple_json" location="..."/>
    <!-- ... other dependencies ... -->
    <cluster name="lib" location="./src/lib/" recursive="true"/>
</target>

<!-- CLI executable target -->
<target name="podcast_forge" extends="forge_lib">
    <root class="FORGE_CLI" feature="make"/>
    <setting name="executable_name" value="podcast-forge"/>
    <cluster name="cli" location="./src/cli/" recursive="true"/>
</target>

<!-- Test target -->
<target name="podcast_forge_tests" extends="forge_lib">
    <root class="TEST_APP" feature="make"/>
    <setting name="executable_name" value="podcast_forge_tests"/>
    <library name="simple_testing" location="$SIMPLE_EIFFEL/simple_testing/simple_testing.ecf"/>
    <cluster name="testing" location="./testing/" recursive="true"/>
</target>
```

---

## Build Commands

```bash
# Compile CLI (workbench for development)
/d/prod/ec.sh -batch -config podcast_forge.ecf -target podcast_forge -c_compile

# Compile CLI (finalized for release)
/d/prod/ec.sh -batch -config podcast_forge.ecf -target podcast_forge -finalize -c_compile

# Run tests
/d/prod/ec.sh -batch -config podcast_forge.ecf -target podcast_forge_tests -c_compile
./EIFGENs/podcast_forge_tests/W_code/podcast_forge_tests.exe

# Run CLI
./EIFGENs/podcast_forge/W_code/podcast-forge.exe new "My Podcast"
```

---

## Success Criteria

| Criterion | Measure | Target |
|-----------|---------|--------|
| Compiles | Zero errors, zero warnings | 100% |
| Tests pass | All test cases | 100% |
| Contracts satisfied | No precondition/postcondition violations | 100% |
| CLI works | All commands documented and functional | 100% |
| Performance | Process 1-hour episode in <12 minutes | 5x real-time |
| Loudness accuracy | Output within 0.5 LUFS of target | 100% |
| Documentation | README, examples, templates | Complete |

---

## File Structure

```
podcast_forge/
+-- podcast_forge.ecf
+-- README.md
+-- LICENSE
+-- src/
|   +-- cli/
|   |   +-- forge_cli.e
|   +-- lib/
|       +-- forge_project.e
|       +-- forge_episode.e
|       +-- forge_manifest.e
|       +-- forge_builder.e
|       +-- forge_normalizer.e
|       +-- forge_assembler.e
|       +-- forge_trimmer.e
|       +-- forge_fader.e
|       +-- forge_publisher.e
|       +-- forge_metadata.e
+-- testing/
|   +-- test_app.e
|   +-- lib_tests.e
|   +-- test_normalizer.e
|   +-- test_assembler.e
|   +-- test_project.e
|   +-- test_builder.e
+-- templates/
|   +-- project/
|   |   +-- interview/
|   |   +-- solo/
|   |   +-- panel/
|   +-- show_notes.md.template
+-- examples/
|   +-- sample-podcast/
|       +-- forge.json
|       +-- assets/
|       +-- episodes/
+-- docs/
    +-- index.html
```
