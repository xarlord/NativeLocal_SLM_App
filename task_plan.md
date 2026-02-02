# Refactoring Plan - NativeLocal_SLM_App

**Project**: Hair Analysis Android App
**Created**: 2026-02-02
**Status**: 🔄 IN_PROGRESS
**Overall Goal**: Refactor codebase to fix architecture violations, eliminate technical debt, and improve code quality

---

## 📋 Executive Summary

**Current Health**: MODERATE (65/100)
**Target Health**: GOOD (85/100)
**Estimated Duration**: 4-5 weeks
**Total Phases**: 5 phases
**Critical Issues**: 5
**High Priority Issues**: 5
**Medium Priority Issues**: 5
**Low Priority Issues**: 5

---

## 🎯 Success Criteria

- [ ] All critical issues resolved (domain/data separation, threading, memory leaks)
- [ ] Clean Architecture compliance ≥ 90%
- [ ] Code quality score ≥ 85/100
- [ ] Test coverage maintained at ≥ 60%
- [ ] All 569 tests passing
- [ ] Real MediaPipe integration implemented
- [ ] Performance requirements met (25-30 FPS, <100ms latency, <300MB memory)

---

## 📊 Phase Overview

| Phase | Focus | Duration | Status | Completion |
|-------|-------|----------|--------|------------|
| **Phase 0** | Discovery & Planning | 2 days | ✅ COMPLETE | 100% |
| **Phase 1** | Critical Fixes | 1 week | 🔄 IN_PROGRESS | 5% |
| **Phase 2** | High Priority Issues | 1 week | 🔄 TODO | 0% |
| **Phase 3** | Medium Priority Issues | 1-2 weeks | 🔄 TODO | 0% |
| **Phase 4** | Low Priority & Polish | 1 week | 🔄 TODO | 0% |
| **Phase 5** | Verification & Documentation | 3-5 days | 🔄 TODO | 0% |

---

## 🚨 Phase 0: Discovery & Planning

**Status**: ✅ COMPLETE
**Duration**: 2 days (completed)
**Agent**: Explore agent (a0cc66a)

### Completed Tasks

- [x] Comprehensive codebase analysis (35 Kotlin files)
- [x] Architecture review and dependency mapping
- [x] Identification of 20 issues across severity levels
- [x] Test coverage analysis (569 tests examined)
- [x] MediaPipe integration assessment
- [x] Build configuration review
- [x] Creation of planning documents

### Key Findings

1. **Critical Architecture Violation**: `ApplyFilterUseCase` depends on data layer models
2. **Main Thread Blocking**: Bitmap conversion in `CameraViewModel` blocks UI
3. **Memory Leaks**: Bitmaps not properly recycled
4. **MediaPipe Stub**: Only placeholder implementation exists
5. **Thread Safety**: `FilterAssetsRepository` cache not thread-safe

### Decisions Made

- ✅ Refactor in phases from critical to low priority
- ✅ Maintain test coverage throughout (≥60%)
- ✅ Run full test suite after each phase
- ✅ Document all changes with commit messages
- ✅ Create feature branches for each phase

---

## 🔥 Phase 1: Critical Fixes (Week 1)

**Status**: 🔄 IN_PROGRESS
**Started**: 2026-02-02
**Duration**: 1 week (estimated)
**Priority**: CRITICAL
**Branch**: `refactor/phase1-critical-fixes`

### Critical Issue #1: Domain/Data Layer Separation

**File**: `domain/usecase/ApplyFilterUseCase.kt`
**Severity**: CRITICAL
**Impact**: Violates Clean Architecture, prevents independent testing

**Steps**:
1. [ ] Create `domain/model/FilterEffect.kt` (move from data)
2. [ ] Create `domain/model/FilterCategory.kt` (move from data)
3. [ ] Create `domain/model/FilterMetadata.kt` (move from data)
4. [ ] Create `domain/repository/FilterRepository.kt` interface
5. [ ] Update `ApplyFilterUseCase` to use domain models
6. [ ] Update `FilterAssetsRepository` to implement `FilterRepository`
7. [ ] Update all imports across codebase
8. [ ] Run tests and fix any breakage

**Verification**:
```bash
# No domain layer imports in use cases
grep -r "import com.example.nativelocal_slm_app.data" domain/
# Should return empty
```

**Tests**:
- [ ] All unit tests pass (408 tests)
- [ ] All instrumented tests pass (161 tests)
- [ ] No data layer imports in domain layer

---

### Critical Issue #2: Main Thread Blocking

**File**: `presentation/camera/CameraViewModel.kt`
**Lines**: 71-74
**Severity**: CRITICAL
**Impact**: UI jank, frame drops, ANR risk

**Steps**:
1. [ ] Update `onCameraFrame()` to use `Dispatchers.Default`
2. [ ] Switch to `Dispatchers.Main` only for UI updates
3. [ ] Ensure `imageProxy.close()` in finally block
4. [ ] Add frame timing metrics
5. [ ] Test frame rate (target: 25-30 FPS)

**Code Change**:
```kotlin
fun onCameraFrame(imageProxy: ImageProxy) {
    if (!isProcessing.compareAndSet(false, true)) {
        imageProxy.close()
        return
    }

    viewModelScope.launch(Dispatchers.Default) {
        try {
            val bitmap = imageProxyToBitmap(imageProxy)
            withContext(Dispatchers.Main) {
                latestOriginalBitmap = bitmap
                // UI updates only
            }
        } finally {
            imageProxy.close()
            isProcessing.set(false)
        }
    }
}
```

**Tests**:
- [ ] Frame rate ≥ 25 FPS under normal load
- [ ] No UI jank with complex filters
- [ ] `imageProxy` always closed (verify with LeakCanary)

---

### Critical Issue #3: Bitmap Memory Leaks

**Files**:
- `presentation/camera/CameraViewModel.kt`
- `data/repository/FilterAssetsRepository.kt`

**Severity**: CRITICAL
**Impact**: OOM crashes, memory growth

**Steps**:

#### Part A: CameraViewModel Bitmap Cleanup
1. [ ] Add `onCleared()` override
2. [ ] Recycle `latestOriginalBitmap`
3. [ ] Recycle `_processedBitmap`
4. [ ] Set to null after recycling
5. [ ] Test with memory profiler

**Code Change**:
```kotlin
override fun onCleared() {
    super.onCleared()
    latestOriginalBitmap?.recycle()
    latestOriginalBitmap = null
    _processedBitmap.value?.recycle()
    _processedBitmap.value = null
}
```

#### Part B: FilterAssetsRepository LRU Cache
1. [ ] Replace `mutableMapOf` with `LruCache`
2. [ ] Set max size to 1/8 of available memory
3. [ ] Implement `sizeOf()` for bitmap estimation
4. [ ] Test memory usage with all filters loaded

**Code Change**:
```kotlin
private val assetCache = LruCache<String, FilterAssets>(
    (Runtime.getRuntime().maxMemory() / 8).toInt()
) {
    override fun sizeOf(key: String, value: FilterAssets): Int {
        return value.mask.byteCount + value.overlay.byteCount
    }
}
```

**Tests**:
- [ ] Memory usage < 300MB with all filters loaded
- [ ] No memory leaks after 100 filter changes
- [ ] LeakCanary shows no leaks

---

### Critical Issue #4: MediaPipe Integration

**File**: `data/repository/MediaPipeHairRepository.kt`
**Severity**: CRITICAL
**Impact**: App doesn't actually analyze hair (stub only)

**Steps**:
1. [ ] Add MediaPipe tasks-vision dependency (if not present)
2. [ ] Implement real `ImageSegmenter` initialization
3. [ ] Implement real `FaceLandmarker` initialization
4. [ ] Implement `analyzeHair()` with real inference
5. [ ] Implement proper `release()` cleanup
6. [ ] Add error handling for model loading failures
7. [ ] Add model loading timeouts
8. [ ] Test with real camera images

**Code Structure**:
```kotlin
class MediaPipeHairRepository(context: Context) : HairAnalysisRepository {
    private val imageSegmenter: ImageSegmenter
    private val faceLandmarker: FaceLandmarker

    init {
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("hair_segmenter.tflite")
            .build()

        val options = ImageSegmenterOptions.builder()
            .setBaseOptions(baseOptions)
            .setOutputType(ImageSegmenterOptions.OutputType.CATEGORY_MASK)
            .build()

        imageSegmenter = ImageSegmenter.createFromOptions(context, options)
        // Similar for faceLandmarker
    }

    override suspend fun analyzeHair(image: Bitmap): HairAnalysisResult {
        // Real MediaPipe inference
    }

    override fun release() {
        imageSegmenter.close()
        faceLandmarker.close()
    }
}
```

**Tests**:
- [ ] Model loads successfully from assets
- [ ] Inference latency < 100ms
- [ ] Returns valid segmentation mask
- [ ] Returns valid face landmarks
- [ ] Proper cleanup on release

---

### Critical Issue #5: Thread-Safety in FilterAssetsRepository

**File**: `data/repository/FilterAssetsRepository.kt`
**Line**: 22
**Severity**: CRITICAL
**Impact**: Crashes on concurrent filter loading

**Steps**:
1. [ ] Replace `mutableMapOf` with `ConcurrentHashMap`
2. [ ] Add double-checked locking for cache access
3. [ ] Ensure atomic check-and-put operations
4. [ ] Test with concurrent filter loading

**Code Change**:
```kotlin
private val assetCache = ConcurrentHashMap<String, FilterAssets>()

suspend fun loadFilterAssets(filterId: String): FilterAssets? = withContext(Dispatchers.IO) {
    assetCache[filterId] ?: synchronized(this) {
        assetCache[filterId] ?: loadFilterAssetsInternal(filterId).also {
            if (it != null) assetCache[filterId] = it
        }
    }
}
```

**Tests**:
- [ ] Concurrent filter loading doesn't crash
- [ ] No duplicate asset loading
- [ ] Cache remains consistent under load

---

## Phase 1 Verification

**Run after completing all critical fixes**:

```bash
# Full test suite
./gradlew check

# Instrumented tests
./gradlew connectedAndroidTest

# Code analysis
./gradlew detekt

# Memory profiling
adb shell dumpsys meminfo com.example.nativelocal_slm_app
```

**Acceptance Criteria**:
- [ ] All 569 tests passing
- [ ] No domain layer imports in data layer
- [ ] Frame rate ≥ 25 FPS
- [ ] Memory usage < 300MB
- [ ] No memory leaks detected
- [ ] MediaPipe integration working

---

## 🎯 Phase 2: High Priority Issues (Week 2)

**Status**: 🔄 TODO
**Duration**: 1 week
**Priority**: HIGH
**Branch**: `refactor/phase2-high-priority`

### High Priority #1: Code Duplication - Bitmap Conversion

**Files**:
- `domain/usecase/ProcessCameraFrameUseCase.kt` (lines 41-48)
- `presentation/camera/CameraViewModel.kt` (lines 137-144)

**Severity**: HIGH
**Impact**: Maintenance burden, potential bugs

**Steps**:
1. [ ] Create `util/ImageConversionUtils.kt`
2. [ ] Extract `imageProxyToBitmap()` to utility
3. [ ] Add proper error handling
4. [ ] Update both call sites
5. [ ] Add unit tests for utility
6. [ ] Remove duplicate code

---

### High Priority #2: Missing FilterAssetsRepository Interface

**File**: `data/repository/FilterAssetsRepository.kt`
**Severity**: HIGH
**Impact**: Tight coupling, difficult to test

**Steps**:
1. [ ] Create `domain/repository/FilterRepository.kt` interface
2. [ ] Define all filter loading methods
3. [ ] Make `FilterAssetsRepository` implement interface
4. [ ] Update DI module to inject interface
5. [ ] Update all usages to use interface
6. [ ] Add tests with mock repository

---

### High Priority #3: Long Method - applyFaceFilter()

**File**: `domain/usecase/ApplyFilterUseCase.kt`
**Lines**: 52-113 (62 lines)
**Severity**: HIGH
**Impact**: Low readability, hard to test

**Steps**:
1. [ ] Extract `scaleMask()` method
2. [ ] Extract `positionMask()` method
3. [ ] Extract `drawMask()` method
4. [ ] Simplify main `applyFaceFilter()` logic
5. [ ] Add unit tests for each extracted method

---

### High Priority #4: Unsafe Null Assertions in Tests

**Files**: Multiple test files
**Severity**: HIGH
**Impact**: Test reliability

**Steps**:
1. [ ] Find all `!!` operators in tests
2. [ ] Replace with `assertNotNull()` + scoping
3. [ ] Add descriptive failure messages
4. [ ] Run all tests to verify
5. [ ] Update test documentation

**Example**:
```kotlin
// Before
result.segmentationMask!!.width

// After
assertNotNull(result.segmentationMask, "segmentationMask should not be null")
result.segmentationMask.let { mask ->
    assertEquals(640, mask.width)
}
```

---

### High Priority #5: SharedPreferences on Main Thread

**File**: `presentation/onboarding/OnboardingViewModel.kt`
**Lines**: 23-24
**Severity**: HIGH
**Impact**: Blocking I/O on main thread

**Steps**:
1. [ ] Wrap SharedPreferences access in coroutine
2. [ ] Use `Dispatchers.IO` for disk operations
3. [ ] Update to use `StateFlow` for reactive state
4. [ ] Test with StrictMode enabled

---

## Phase 2 Verification

**Acceptance Criteria**:
- [ ] No code duplication (verified by detekt)
- [ ] All repositories use interfaces
- [ ] No methods > 30 lines
- [ ] No `!!` operators in tests
- [ ] No disk I/O on main thread
- [ ] All 569 tests passing

---

## 🔧 Phase 3: Medium Priority Issues (Weeks 3-4)

**Status**: 🔄 TODO
**Duration**: 1-2 weeks
**Priority**: MEDIUM
**Branch**: `refactor/phase3-medium-priority`

### Medium Priority #1: God Class - FilterCarousel.kt

**File**: `presentation/filters/FilterCarousel.kt`
**Lines**: 312
**Severity**: MEDIUM
**Impact**: Low maintainability

**Steps**:
1. [ ] Extract `FilterGridView.kt` composable
2. [ ] Extract `FilterSelectionViewModel.kt`
3. [ ] Simplify `FilterCarousel.kt` to < 150 lines
4. [ ] Update tests for new structure

---

### Medium Priority #2: God Class - ResultsScreen.kt

**File**: `presentation/results/ResultsScreen.kt`
**Lines**: 264
**Severity**: MEDIUM

**Steps**:
1. [ ] Extract `ShareHelper.kt` utility
2. [ ] Extract `HistoryManager.kt` class
3. [ ] Simplify `ResultsScreen.kt` to < 150 lines
4. [ ] Update tests

---

### Medium Priority #3: Error Handling in Use Cases

**Files**: All use case files
**Severity**: MEDIUM
**Impact**: Crashes on invalid input

**Steps**:
1. [ ] Define `Result<T>` wrapper for use case returns
2. [ ] Add try-catch blocks in all use cases
3. [ ] Return specific error types
4. [ ] Update ViewModels to handle errors
5. [ ] Add error UI states
6. [ ] Test error scenarios

---

### Medium Priority #4: Koin Major Version Upgrade

**Current**: 3.5.6
**Target**: 4.0.0
**Severity**: MEDIUM
**Impact**: Breaking changes

**Steps**:
1. [ ] Review Koin 4.0 migration guide
2. [ ] Update dependency version
3. [ ] Update module definitions (new syntax)
4. [ ] Update all injection calls
5. [ ] Test all DI scenarios
6. [ ] Update documentation

---

### Medium Priority #5: Inefficient YUV Conversion

**File**: `domain/usecase/ProcessCameraFrameUseCase.kt`
**Lines**: 54-86
**Severity**: MEDIUM
**Impact**: GC pressure, frame drops

**Steps**:
1. [ ] Evaluate RenderScript approach
2. [ ] Implement optimized YUV to NV21 conversion
3. [ ] Reduce intermediate byte array allocations
4. [ ] Benchmark performance improvement
5. [ ] Ensure frame rate improvement

---

## Phase 3 Verification

**Acceptance Criteria**:
- [ ] No files > 200 lines
- [ ] All use cases return `Result<T>`
- [ ] Koin 4.0 successfully integrated
- [ ] YUV conversion latency reduced by ≥ 30%
- [ ] All 569 tests passing

---

## ✨ Phase 4: Low Priority & Polish (Week 5)

**Status**: 🔄 TODO
**Duration**: 1 week
**Priority**: LOW
**Branch**: `refactor/phase4-low-priority`

### Low Priority #1: Inconsistent ViewModel Creation

**Files**: Multiple ViewModels
**Severity**: LOW

**Steps**:
1. [ ] Audit all ViewModel creations
2. [ ] Add `OnboardingViewModel` to Koin module
3. [ ] Update MainActivity to use Koin
4. [ ] Document DI pattern

---

### Low Priority #2: Unused Imports & Code Style

**Files**: 21 files with wildcard imports
**Severity**: LOW

**Steps**:
1. [ ] Run `./gradlew detekt`
2. [ ] Fix all wildcard imports
3. [ ] Remove unused imports
4. [ ] Enable ktlint formatter
5. [ ] Run on entire codebase

---

### Low Priority #3: Deprecated Gradle Syntax

**File**: `app/build.gradle.kts`
**Line**: 10
**Severity**: LOW

**Steps**:
1. [ ] Change `version = release(36)` to `compileSdk = 36`
2. [ ] Verify build still works
3. [ ] Check for any other deprecated syntax

---

### Low Priority #4: minSdk Mismatch

**Current**: minSdk = 33
**Documented**: minSdk = 24
**Severity**: LOW

**Steps**:
1. [ ] Decide on target minSdk (recommend 24 for broader support)
2. [ ] Update `build.gradle.kts` if lowering to 24
3. [ ] Update CLAUDE.md if keeping at 33
4. [ ] Verify app works on chosen minSdk

---

### Low Priority #5: Performance Tests

**Severity**: LOW
**Impact**: No performance regression detection

**Steps**:
1. [ ] Create `performance/FPSMeter.kt`
2. [ ] Create `performance/LatencyTracker.kt`
3. [ ] Create `performance/MemoryProfiler.kt`
4. [ ] Add baseline measurements
5. [ ] Add regression tests
6. [ ] Document performance requirements

---

## Phase 4 Verification

**Acceptance Criteria**:
- [ ] All ViewModels use Koin
- [ ] No wildcard imports
- [ ] No deprecated Gradle syntax
- [ ] minSdk consistent with documentation
- [ ] Performance tests passing
- [ ] All 569 tests passing

---

## ✅ Phase 5: Verification & Documentation (3-5 days)

**Status**: 🔄 TODO
**Duration**: 3-5 days
**Priority**: CRITICAL (final gate)

### Final Verification Steps

#### 1. Full Test Suite
```bash
# Unit tests
./gradlew test

# Instrumented tests
./gradlew connectedAndroidTest

# Coverage report
./gradlew jacocoTestReport
```

**Acceptance**:
- [ ] All 569 tests passing
- [ ] Coverage ≥ 60%
- [ ] No flaky tests

#### 2. Performance Validation
```bash
# FPS test
adb shell dumpsys gfxinfo com.example.nativelocal_slm_app

# Memory test
adb shell dumpsys meminfo com.example.nativelocal_slm_app
```

**Acceptance**:
- [ ] FPS ≥ 25 (target: 30)
- [ ] Memory < 300MB
- [ ] Filter latency < 100ms

#### 3. Architecture Review
```bash
# Check for domain layer dependencies on data
grep -r "import.*data" domain/

# Check for main thread blocking
grep -r "Dispatchers.Main" presentation/

# Check for proper abstraction
grep -r "new FilterAssetsRepository" . --include="*.kt"
```

**Acceptance**:
- [ ] No domain → data dependencies
- [ ] No blocking on main thread
- [ ] All use interfaces

#### 4. Memory Leak Detection
```bash
# Run with LeakCanary
./gradlew installDebug

# Trigger scenarios
# - 100 camera start/stop cycles
# - 100 filter changes
# - 50 photo captures
```

**Acceptance**:
- [ ] No leaks detected
- [ ] Memory stable over time
- [ ] Bitmaps properly recycled

#### 5. E2E Testing
**Manual scenarios**:
1. [ ] Happy Path - Basic Filter
2. [ ] Color Change Workflow
3. [ ] Before-After Comparison
4. [ ] Memory Pressure Test
5. [ ] Camera Performance Test

**Acceptance**:
- [ ] All 5 scenarios pass
- [ ] No crashes
- [ ] No ANRs

---

### Documentation Updates

1. [ ] Update CLAUDE.md with new architecture
2. [ ] Update README.md with build instructions
3. [ ] Create MIGRATION_GUIDE.md for changes
4. [ ] Update API documentation
5. [ ] Create REFACTORING_SUMMARY.md

---

### Final Sign-Off

**Code Review Checklist**:
- [ ] All phases complete
- [ ] All tests passing
- [ ] Performance requirements met
- [ ] Architecture violations fixed
- [ ] Documentation updated
- [ ] No regressions introduced

**Merge Approval**:
- [ ] Technical lead approval
- [ ] Code review completed
- [ ] CI/CD pipeline passing
- [ ] Ready for production

---

## 📝 Error Log

| Error | Phase | Attempt | Resolution | Date |
|-------|-------|---------|------------|------|
| TBD | - | - | - | - |

---

## 🔗 Resources

### Key Files
- Architecture: `CLAUDE.md`
- Build Config: `app/build.gradle.kts`
- Dependencies: `gradle/libs.versions.toml`
- DI Setup: `presentation/di/AppModule.kt`

### Documentation
- Clean Architecture: https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html
- Android Best Practices: https://developer.android.com/quality
- MediaPipe Docs: https://developers.google.com/mediapipe
- Koin DI: https://insert-koin.io/docs/setup/koin

### Tools
- Detekt: Static analysis
- LeakCanary: Memory leak detection
- JaCoCo: Code coverage
- Android Profiler: Performance monitoring

---

## 📈 Progress Metrics

**Started**: 2026-02-02
**Last Updated**: 2026-02-02
**Current Phase**: Phase 0 (Discovery)
**Completion**: 10% (planning complete)

### Issues by Status

| Severity | Total | Open | In Progress | Closed |
|----------|-------|------|-------------|--------|
| Critical | 5 | 5 | 0 | 0 |
| High | 5 | 5 | 0 | 0 |
| Medium | 5 | 5 | 0 | 0 |
| Low | 5 | 5 | 0 | 0 |
| **Total** | **20** | **20** | **0** | **0** |

---

**Next Steps**: Review plan with user, obtain approval, begin Phase 1
