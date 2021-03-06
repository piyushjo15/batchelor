# This tests the functions related to multiBatchPCA.
# library(batchelor); library(testthat); source("setup.R"); source("test-multi-pca.R")

expect_equal_besides_sign <- function(left, right, ...) {
    ratio <- left/right
    right2 <- sweep(right, 2, sign(ratio[1,]), FUN="*")
    expect_equal(left, right2, ...)
}

set.seed(1200001)
test_that("multi-sample PCA works as expected", {
    test1 <- matrix(rnorm(1000), nrow=10)
    test2 <- matrix(rnorm(2000), nrow=10)

    # Checking that we get the same result independent of the multiples of the data. 
    ref <- multiBatchPCA(test1, test2, d=5)
    out <- multiBatchPCA(test1, cbind(test2, test2), d=5)
    expect_equal_besides_sign(ref[[1]], out[[1]])
    expect_equal_besides_sign(rbind(ref[[2]], ref[[2]]), out[[2]])
    expect_identical(ncol(ref[[1]]), 5L)
    expect_identical(ncol(ref[[2]]), 5L)

    # Another check. 
    ref <- multiBatchPCA(test1, test2, d=3)
    out <- multiBatchPCA(cbind(test1, test1, test1), test2, d=3)
    expect_equal_besides_sign(ref[[2]], out[[2]])
    expect_equal_besides_sign(rbind(ref[[1]], ref[[1]], ref[[1]]), out[[1]])
    expect_identical(ncol(ref[[1]]), 3L)
    expect_identical(ncol(ref[[2]]), 3L)

    # Checking with equal numbers of cells - should be equivalent to cbind'd PCA. 
    test3 <- matrix(rnorm(1000), nrow=10)
    out <- multiBatchPCA(test1, test3, d=4)
    ref <- prcomp(t(cbind(test1, test3)), rank.=4)
    expect_equal_besides_sign(rbind(out[[1]], out[[2]]), unname(ref$x))
    
    # Checking that the distances match up to the original values when we use full rank.
    out <- multiBatchPCA(test1, test2, d=nrow(test1))

    everything <- rbind(t(test1), t(test2))
    ref.dist <- as.matrix(dist(everything))
    out.dist <- as.matrix(dist(rbind(out[[1]], out[[2]])))
    expect_equal(ref.dist, out.dist)
    
    out2 <- multiBatchPCA(test1, cbind(test2, test2), d=nrow(test1))
    out.dist2 <- as.matrix(dist(do.call(rbind, as.list(out2))))
    everything2 <- rbind(everything, t(test2))
    ref.dist2 <- as.matrix(dist(everything2)) 
    expect_equal(out.dist2, ref.dist2)

    # Throws an error on mismatched dimensions.
    expect_error(multiBatchPCA(test1, test2[0,,drop=FALSE]), "not the same")
})

set.seed(12000011)
test_that("multi-sample PCA works with subsetting", {
    test1 <- matrix(rnorm(1000), nrow=10)
    test2 <- matrix(rnorm(2000), nrow=10)

    i <- sample(nrow(test1), 5)
    ref <- multiBatchPCA(test1, test2, d=3, subset.row=i)
    out <- multiBatchPCA(test1[i,], test2[i,], d=3)
    expect_equal(ref, out)

    l <- rbinom(nrow(test1), 1, 0.5)==1
    ref <- multiBatchPCA(test1, test2, d=3, subset.row=l)
    out <- multiBatchPCA(test1[l,], test2[l,], d=3)
    expect_equal(ref, out) 
})

set.seed(120000111)
test_that("multi-sample PCA works with other matrix representations", {
    test1 <- matrix(rnorm(1000), nrow=10)
    test2 <- matrix(rnorm(2000), nrow=10)
    ref <- multiBatchPCA(test1, test2, d=4)
    out <- multiBatchPCA(DelayedArray(test1), DelayedArray(test2), d=4)
    expect_equal(ref, out)

    combined <- cbind(test1, test2)
    batch <- rep(1:2, c(ncol(test1), ncol(test2)))
    ref <- multiBatchPCA(combined, batch=batch, d=4)
    out <- multiBatchPCA(DelayedArray(combined), batch=batch, d=4)
    expect_equal(ref, out)
})

set.seed(12000012)
test_that("multi-sample PCA works with SCEs", {
    test1 <- matrix(rnorm(1000), nrow=8)
    test2 <- matrix(rnorm(2000), nrow=8)
    sce1 <- SingleCellExperiment(list(logcounts=test1))
    sce2 <- SingleCellExperiment(list(logcounts=test2))

    ref <- multiBatchPCA(sce1, sce2, d=4)
    out <- multiBatchPCA(test1, test2, d=4)
    expect_equal(ref, out)

    # Subsetting works correctly.
    i <- sample(nrow(test1), 5)
    ref <- multiBatchPCA(sce1, sce2, d=2, subset.row=i)
    out <- multiBatchPCA(sce1[i,], sce2[i,], d=2)
    expect_equal(ref, out)
})

set.seed(1200002)
test_that("multi-sample PCA rotation vector inference works", {
    test1 <- matrix(rnorm(1000), nrow=10)
    test2 <- matrix(rnorm(2000), nrow=10)
    ref <- multiBatchPCA(test1, test2, d=5)

    # Checking that the rotation vectors and centers are sensible, for starters.
    expect_identical(length(metadata(ref)$centers), nrow(test1))
    expect_identical(dim(metadata(ref)$rotation), c(nrow(test1), 5L))
    expect_equal(ref[[1]], crossprod(test1 - metadata(ref)$centers, metadata(ref)$rotation))
    expect_equal(ref[[2]], crossprod(test2 - metadata(ref)$centers, metadata(ref)$rotation))

    # Checking that expansion works.
    others <- c(7, 3, 1, 2)
    N <- nrow(test1)
    expanded <- c(seq_len(N), others)
    out <- multiBatchPCA(test1[expanded,], test2[expanded,], d=5, subset.row=1:N, get.all.genes=TRUE)

    expect_equal(ref[[1]], out[[1]])
    expect_equal(ref[[2]], out[[2]])
    expect_equal(metadata(ref)$rotation[expanded,], metadata(out)$rotation)

    # Also works with a logical vector for subsetting. 
    alt <- multiBatchPCA(test1[expanded,], test2[expanded,], d=5, subset.row=seq_along(expanded) <= N, get.all.genes=TRUE)
    expect_equal(alt, out)

    # Center expansion also works.
    expect_equal(metadata(ref)$centers[expanded], metadata(out)$centers) 
})

set.seed(12000021)
test_that("multi-sample PCA works with a single input", {
    test1 <- matrix(rnorm(1000), nrow=10)
    test2 <- matrix(rnorm(2000), nrow=10)
    ref <- multiBatchPCA(test1, test2, d=5)

    combined <- cbind(test1, test2)
    batch <- rep(1:2, c(ncol(test1), ncol(test2)))
    out <- multiBatchPCA(combined, batch=batch, d=5)
    expect_identical(ref, unname(out))
    expect_identical(names(out), as.character(1:2))

    out2 <- multiBatchPCA(combined, batch=batch, d=5, preserve.single=TRUE)
    expect_identical(rbind(ref[[1]], ref[[2]]), out2[[1]])
    expect_identical(metadata(ref), metadata(out2))

    # Handles reordering.
    o <- sample(length(batch))
    alt <- multiBatchPCA(combined[,o,drop=FALSE], batch=batch[o], d=5, preserve.single=TRUE)
    expect_equal(out2[[1]][o,], alt[[1]])
    expect_equal(metadata(out2), metadata(alt))

    # Handles subsetting.
    i <- 1:5
    ref <- multiBatchPCA(combined[i,], batch=batch, d=5)
    out <- multiBatchPCA(combined, batch=batch, subset.row=i, d=5)
    expect_equal(ref, out)

    # Expected errors.
    expect_error(multiBatchPCA(), "at least one batch")
    expect_error(multiBatchPCA(test1), "'batch' must be specified")
})

set.seed(1200003)
test_that("multi-sample PCA preserves dimension names in the output", {
    test1 <- matrix(rnorm(1000), nrow=10)
    test2 <- matrix(rnorm(2000), nrow=10)

    # Respects batch names themselves.
    out <- multiBatchPCA(A=test1, V=test2, d=3)
    expect_identical(names(out), c("A", "V"))

    # Preserves row names in rotation vectors and centering vectors.
    rownames(test1) <- rownames(test2) <- LETTERS[sample(nrow(test1))]
    out <- multiBatchPCA(test1, test2, d=3)
    expect_identical(rownames(test1), rownames(metadata(out)$rotation))
    expect_identical(rownames(test1), names(metadata(out)$centers))

    out <- multiBatchPCA(test1, test2, d=3, subset.row=2:6)
    expect_identical(rownames(test1)[2:6], rownames(metadata(out)$rotation))
    expect_identical(rownames(test1)[2:6], names(metadata(out)$centers))

    out <- multiBatchPCA(test1, test2, d=3, subset.row=2:6, get.all.genes=TRUE)
    expect_identical(rownames(test1), rownames(metadata(out)$rotation))
    expect_identical(rownames(test1), names(metadata(out)$centers))

    # Preserves column names.
    test1 <- matrix(rnorm(1000), nrow=10)
    colnames(test1) <- sprintf("CELL_%i", seq_len(ncol(test1)))
    test2 <- matrix(rnorm(2000), nrow=10)
    colnames(test2) <- sprintf("CELL2_%i", seq_len(ncol(test2)))
    
    out <- multiBatchPCA(test1, test2, d=3)
    expect_identical(rownames(out[[1]]), colnames(test1))
    expect_identical(rownames(out[[2]]), colnames(test2))

    # ... even when they're non-unique.
    test2 <- matrix(rnorm(2000), nrow=10)
    colnames(test2) <- sprintf("CELL_%i", seq_len(ncol(test2)))
    out <- multiBatchPCA(test1, test2, d=3)
    expect_identical(rownames(out[[1]]), colnames(test1))
    expect_identical(rownames(out[[2]]), colnames(test2))
})

set.seed(12000031)
test_that("multi-sample PCA preserves dimension names for single inputs", {
    test1 <- matrix(rnorm(1000), nrow=10)
    test2 <- matrix(rnorm(2000), nrow=10)

    combined <- cbind(test1, test2)
    batch <- rep(1:2, c(ncol(test1), ncol(test2)))
    out <- multiBatchPCA(combined, batch=batch, d=5)
    expect_identical(rownames(out[[1]]), colnames(test1))
    expect_identical(rownames(out[[2]]), colnames(test2))

    out <- multiBatchPCA(combined, batch=batch, d=5, preserve.single=TRUE)
    expect_identical(rownames(out[[1]]), c(colnames(test1), colnames(test2)))

    # What happens with reordering.
    o <- sample(length(batch))
    out <- multiBatchPCA(combined[,o], batch=batch[o], d=5, preserve.single=TRUE)
    expect_identical(rownames(out[[1]]), c(colnames(test1), colnames(test2))[o])

    out <- multiBatchPCA(combined[,o], batch=batch[o], d=5)
    expect_identical(c(rownames(out[[1]]), rownames(out[[2]])), c(colnames(test1), colnames(test2))[o])
})

set.seed(1200004)
test_that("multi-sample PCA correctly computes the variance explained", {
    test1 <- matrix(rnorm(1000), nrow=20)
    test2 <- matrix(rnorm(2000), nrow=20)
    test3 <- matrix(rnorm(3000), nrow=20)

    # Total variance calculations match up.
    out <- multiBatchPCA(test1, test2, test3, get.variance=TRUE, d=20)
    expect_equal(sum(metadata(out)$var.explained), metadata(out)$var.total)

    manual.val <- 0
    everything <- list(test1, test2, test3)
    manual.center <- Reduce("+", lapply(everything, rowMeans))/length(everything)
    for (test in everything) {
        manual.val <- manual.val + sum(rowMeans((test - manual.center)^2))
    }
    expect_equal(manual.val/length(everything), metadata(out)$var.total)

    # Number of dimensions to retain doesn't affect the result.
    alt <- multiBatchPCA(test1, test2, test3, get.variance=TRUE, d=10)
    expect_equal(metadata(out)$var.explained[1:10], metadata(alt)$var.explained)
    expect_equal(metadata(out)$var.total, metadata(alt)$var.total)

    # Individual PCs make sense as well.
    for (i in seq_len(10)) {
        stuff <- lapply(alt, function(x) x[,i])
        expect_equal(sum(sapply(stuff, mean)), 0)
        expect_equal(mean(sapply(stuff, function(x) mean(x^2))), metadata(out)$var.explained[i])
    }
})

set.seed(1200005)
test_that("multi-sample PCA works with deferred operations", {
    test1 <- matrix(rnorm(1000), nrow=20)
    test2 <- matrix(rnorm(2000), nrow=20)
    test3 <- matrix(rnorm(3000), nrow=20)

    # Testing the output of the matrix processor.        
    everything <- list(test1, test2, test3)
    ref <- batchelor:::.process_listed_matrices_for_pca(everything, NULL, NULL, deferred=FALSE)
    out <- batchelor:::.process_listed_matrices_for_pca(everything, NULL, NULL, deferred=TRUE)
    expect_equal(as.matrix(ref$scaled), as.matrix(out$scaled))
    expect_equal(lapply(ref$centered, as.matrix), lapply(out$centered, as.matrix))

    expect_s4_class(ref$scaled, "DelayedMatrix")
    expect_s4_class(out$scaled, "DeferredMatrix")
    expect_s4_class(ref$centered[[1]], "DelayedMatrix")
    expect_s4_class(out$centered[[1]], "DeferredMatrix")

    # Comparing the output.
    ref <- multiBatchPCA(test1, test2, test3, d=20)
    out <- multiBatchPCA(test1, test2, test3, d=20, BSPARAM=BiocSingular::ExactParam(deferred=TRUE))
    expect_equal(ref, out)

    ref <- multiBatchPCA(test1, test2, test3, d=10, get.variance=TRUE)
    out <- multiBatchPCA(test1, test2, test3, d=10, get.variance=TRUE, BSPARAM=BiocSingular::ExactParam(deferred=TRUE))
    expect_equal(metadata(ref), metadata(out))

    ref <- multiBatchPCA(test1, test2, test3, d=10, subset.row=5:15, get.all.genes=TRUE)
    out <- multiBatchPCA(test1, test2, test3, d=10, subset.row=5:15, get.all.genes=TRUE, 
        BSPARAM=BiocSingular::ExactParam(deferred=TRUE))
    expect_equal(metadata(ref), metadata(out))

    # Also works with single inputs.
    everything <- cbind(test1, test2, test3)
    b <- rep(LETTERS[1:3], c(ncol(test1), ncol(test2), ncol(test3)))
    ref <- batchelor:::.process_single_matrix_for_pca(everything, b, NULL, NULL, deferred=FALSE)
    out <- batchelor:::.process_single_matrix_for_pca(everything, b, NULL, NULL, deferred=TRUE)
    expect_equal(as.matrix(ref$scaled), as.matrix(out$scaled))
    expect_equal(as.matrix(ref$centered), as.matrix(out$centered))

    ref <- multiBatchPCA(everything, batch=b, d=20)
    out <- multiBatchPCA(everything, batch=b, d=20, BSPARAM=BiocSingular::ExactParam(deferred=TRUE))
    expect_equal(ref, out)
})

set.seed(1200006)
test_that("multi-sample PCA works with additional weights", {
              library(testthat); library(batchelor)
    test1 <- matrix(rnorm(1000), nrow=10)
    test2 <- matrix(rnorm(2000), nrow=10)

    ref <- multiBatchPCA(test1, test2, d=5)
    reweighted <- multiBatchPCA(test1, test1, test2, d=5, weights=c(0.5, 0.5, 1))
    expect_equal(ref[[1]], reweighted[[1]])
    expect_equal(ref[[2]], reweighted[[3]])

    # Recovering PCA by weighting with the number of cells.
    reweighted <- multiBatchPCA(test1, test2, d=5, weights=c(ncol(test1), ncol(test2)))
    ref <- prcomp(t(cbind(test1, test2)), rank.=5)
    expect_equal_besides_sign(rbind(reweighted[[1]], reweighted[[2]]), unname(ref$x))

    # Works within a single batch as well.
    combined <- cbind(test1, test2, test2)
    batch <- rep(1:3, c(ncol(test1), ncol(test2), ncol(test2)))

    o <- sample(length(batch))
    single <- multiBatchPCA(combined[,o], batch=batch[o], d=5, weights=c(`1`=1, `2`=0.5, `3`=0.5), preserve.single=TRUE)
    ref <- multiBatchPCA(test1, test2, test2, d=5, weights=c(1, 0.5, 0.5))
    expect_equal_besides_sign(single[[1]], rbind(ref[[1]], ref[[2]], ref[[3]])[o,])

    # Throwing all the safety errors.
    expect_error(multiBatchPCA(test1, test2, d=5, weights=c(1), "same as number of entries"))
    expect_error(multiBatchPCA(A=test1, B=test2, d=5, weights=c(A=1, B=0.5), "same as names"))
    expect_error(multiBatchPCA(combined, batch=batch, d=5, weights=c(A=1), "should be named"))
})

