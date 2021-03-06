% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/multiBatchPCA.R
\name{multiBatchPCA}
\alias{multiBatchPCA}
\title{Multi-batch PCA}
\usage{
multiBatchPCA(
  ...,
  batch = NULL,
  d = 50,
  subset.row = NULL,
  weights = NULL,
  get.all.genes = FALSE,
  get.variance = FALSE,
  preserve.single = FALSE,
  assay.type = "logcounts",
  BSPARAM = ExactParam(),
  BPPARAM = SerialParam()
)
}
\arguments{
\item{...}{Two or more matrices containing expression values (usually log-normalized).
Each matrix is assumed to represent one batch and should contain the same number of rows, corresponding to the same genes (in the same order).

Alternatively, two or more \linkS4class{SingleCellExperiment} objects containing these matrices.
Note the same restrictions described above for gene expression matrix inputs.

Alternatively, one matrix or SingleCellExperiment can be supplied containing cells from all batches. 
This requires \code{batch} to also be specified.}

\item{batch}{A factor specifying the batch identity of each cell in the input data.
Ignored if \code{...} contains more than one argument.}

\item{d}{An integer scalar specifying the number of dimensions to keep from the initial multi-sample PCA.}

\item{subset.row}{A vector specifying which features to use for correction.}

\item{weights}{Numeric vector of length equal to the number of entries in \code{...}, specifying the scaling of the weight of each batch.
This defaults to 1 for all batches.}

\item{get.all.genes}{A logical scalar indicating whether the reported rotation vectors should include genes 
that are excluded by a non-\code{NULL} value of \code{subset.row}.}

\item{get.variance}{A logical scalar indicating whether to return the (weighted) variance explained by each PC.}

\item{preserve.single}{A logical scalar indicating whether to combine the results into a single matrix if only one object was supplied in \code{...}.}

\item{assay.type}{A string or integer scalar specifying the assay containing the expression values, if SingleCellExperiment objects are present in \code{...}.}

\item{BSPARAM}{A \linkS4class{BiocSingularParam} object specifying the algorithm to use for PCA, see \code{\link{runSVD}} for details.}

\item{BPPARAM}{A \linkS4class{BiocParallelParam} object specifying whether the SVD should be parallelized.}
}
\value{
A \linkS4class{List} of numeric matrices is returned where each matrix corresponds to a batch and contains the first \code{d} PCs (columns) for all cells in the batch (rows).

If \code{preserve.single=TRUE} and \code{...} contains a single object, the List will only contain a single matrix.
This contains the first \code{d} PCs (columns) for all cells in the same order as supplied in the single input object.

The metadata contains \code{rotation}, a matrix of rotation vectors, which can be used to construct a low-rank approximation of the input matrices.
This has number of rows equal to the number of genes after any subsetting, except if \code{get.all.genes=TRUE}, where the number of rows is equal to the genes before subsetting.

If \code{get.variance=TRUE}, the metadata will also contain \code{var.explained}, the weighted variance explained by each PC;
and \code{var.total}, the total variance after weighting.
}
\description{
Perform a principal components analysis across multiple gene expression matrices to project all cells to a common low-dimensional space.
}
\details{
This function is roughly equivalent to \code{cbind}ing all matrices in \code{...} and performing PCA on the merged matrix.
The main difference is that each sample is forced to contribute equally to the identification of the rotation vectors.
Specifically, the mean vector used for centering is defined as the grand mean of the mean vectors within each batch.
Each batch's contribution to the gene-gene covariance matrix is also divided by the number of cells in that batch.

Our approach is to effectively weight the cells in each batch to mimic the situation where all batches have the same number of cells.
This ensures that the low-dimensional space can distinguish subpopulations in smaller batches.
Otherwise, batches with a large number of cells would dominate the PCA, i.e., the definition of the mean vector and covariance matrix.
This may reduce resolution of unique subpopulations in smaller batches that differ in a different dimension to the subspace of the larger batches.

When \code{weights} is set, this will scale the weight of each batch by the specified value. 
For example, each batch may represent one replicate, with multiple replicates per study.
In such cases, it may be more appropriate to ensure that each \emph{study} has equal weight.
This is done by assigning a value of \code{weights} to each replicate that is inversely proportional to the number of replicates in the same study - see Examples.

Setting \code{get.all.genes=TRUE} will report rotation vectors that span all genes, even when only a subset of genes are used for the PCA.
This is done by projecting all non-used genes into the low-dimensional \dQuote{cell space} defined by the first \code{d} components.

If \code{BSPARAM} is defined with \code{deferred=TRUE}, the per-gene centering and per-cell scaling will be manually deferred during matrix multiplication.
This can greatly improve speeds when the input matrices are sparse, as deferred operations avoids loss of sparsity (at the cost of numerical precision).
}
\examples{
d1 <- matrix(rnorm(5000), ncol=100)
d1[1:10,1:10] <- d1[1:10,1:10] + 2 # unique population in d1
d2 <- matrix(rnorm(2000), ncol=40)
d2[11:20,1:10] <- d2[11:20,1:10] + 2 # unique population in d2

out <- multiBatchPCA(d1, d2)

# Examining results.
xlim <- range(c(out[[1]][,1], out[[2]][,1]))
ylim <- range(c(out[[1]][,2], out[[2]][,2]))
plot(out[[1]][,1], out[[1]][,2], col="red", xlim=xlim, ylim=ylim)
points(out[[2]][,1], out[[2]][,2], col="blue") 

# Using the weighting scheme, assuming that 'd2' and 'd3'
# are replicates and should contribute the same combined
# weight as 'd1'.
d3 <- d2 + 5
out <- multiBatchPCA(d1, d2, d3, weights=c(1, 0.5, 0.5))

}
\seealso{
\code{\link{runSVD}}
}
\author{
Aaron Lun
}
