% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mnnCorrect.R
\name{mnnCorrect}
\alias{mnnCorrect}
\title{Mutual nearest neighbors correction}
\usage{
mnnCorrect(
  ...,
  batch = NULL,
  restrict = NULL,
  k = 20,
  prop.k = NULL,
  sigma = 0.1,
  cos.norm.in = TRUE,
  cos.norm.out = TRUE,
  svd.dim = 0L,
  var.adj = TRUE,
  subset.row = NULL,
  correct.all = FALSE,
  merge.order = NULL,
  auto.merge = FALSE,
  assay.type = "logcounts",
  BSPARAM = ExactParam(),
  BNPARAM = KmknnParam(),
  BPPARAM = SerialParam()
)
}
\arguments{
\item{...}{One or more log-expression matrices where genes correspond to rows and cells correspond to columns.
Alternatively, one or more \linkS4class{SingleCellExperiment} objects can be supplied containing a log-expression matrix in the \code{assay.type} assay.
Each object should contain the same number of rows, corresponding to the same genes in the same order.
Objects of different types can be mixed together.

If multiple objects are supplied, each object is assumed to contain all and only cells from a single batch.
If a single object is supplied, it is assumed to contain cells from all batches, so \code{batch} should also be specified.

Alternatively, one or more lists of such objects can be provided, which may be more convenient for programmatic use.}

\item{batch}{A factor specifying the batch of origin for all cells when only a single object is supplied in \code{...}.
This is ignored if multiple objects are present.}

\item{restrict}{A list of length equal to the number of objects in \code{...}.
Each entry of the list corresponds to one batch and specifies the cells to use when computing the correction.}

\item{k}{An integer scalar specifying the number of nearest neighbors to consider when identifying MNNs.}

\item{prop.k}{A numeric scalar in (0, 1) specifying the proportion of cells in each dataset to use for mutual nearest neighbor searching.
If set, \code{k} for the search in each batch is redefined as \code{max(k, prop.k*N)} where \code{N} is the number of cells in that batch.}

\item{sigma}{A numeric scalar specifying the bandwidth of the Gaussian smoothing kernel used to compute the correction vector for each cell.}

\item{cos.norm.in}{A logical scalar indicating whether cosine normalization should be performed on the input data prior to calculating distances between cells.}

\item{cos.norm.out}{A logical scalar indicating whether cosine normalization should be performed prior to computing corrected expression values.}

\item{svd.dim}{An integer scalar specifying the number of dimensions to use for summarizing biological substructure within each batch.}

\item{var.adj}{A logical scalar indicating whether variance adjustment should be performed on the correction vectors.}

\item{subset.row}{A vector specifying which features to use for correction.}

\item{correct.all}{A logical scalar specifying whether correction should be applied to all genes, even if only a subset is used for the MNN calculations.}

\item{merge.order}{An integer vector containing the linear merge order of batches in \code{...}.
Alternatively, a list of lists representing a tree structure specifying a hierarchical merge order.}

\item{auto.merge}{Logical scalar indicating whether to automatically identify the \dQuote{best} merge order.}

\item{assay.type}{A string or integer scalar specifying the assay containing the log-expression values.
Only used for SingleCellExperiment inputs.}

\item{BSPARAM}{A \linkS4class{BiocSingularParam} object specifying the algorithm to use for PCA.
This uses a fast approximate algorithm from \pkg{irlba} by default, see \code{\link{multiBatchPCA}} for details.}

\item{BNPARAM}{A \linkS4class{BiocNeighborParam} object specifying the nearest neighbor algorithm.}

\item{BPPARAM}{A \linkS4class{BiocParallelParam} object specifying whether the PCA and nearest-neighbor searches should be parallelized.}
}
\value{
A \linkS4class{SingleCellExperiment} object containing the \code{corrected} assay.
This contains corrected expression values for each gene (row) in each cell (column) in each batch.
A \code{batch} field is present in the column data, specifying the batch of origin for each cell.

Cells in the output object are always ordered in the same manner as supplied in \code{...}.
For a single input object, cells will be reported in the same order as they are arranged in that object.
In cases with multiple input objects, the cell identities are simply concatenated from successive objects,
i.e., all cells from the first object (in their provided order), then all cells from the second object, and so on.

The metadata of the SingleCellExperiment contains \code{merge.info}, a DataFrame where each row corresponds to a merge step.
See \dQuote{Merge diagnostics} for more information.
}
\description{
Correct for batch effects in single-cell expression data using the mutual nearest neighbors method.
}
\details{
This function is designed for batch correction of single-cell RNA-seq data where the batches are partially confounded with biological conditions of interest.
It does so by identifying pairs of mutual nearest neighbors (MNN) in the high-dimensional log-expression space.
Each MNN pair represents cells in different batches that are of the same cell type/state, assuming that batch effects are mostly orthogonal to the biological manifold.
Correction vectors are calculated from the pairs of MNNs and corrected (log-)expression values are returned for use in clustering and dimensionality reduction.

For each MNN pair, a pairwise correction vector is computed based on the difference in the log-expression profiles.
The correction vector for each cell is computed by applying a Gaussian smoothing kernel with bandwidth \code{sigma} is the pairwise vectors.
This stabilizes the vectors across many MNN pairs and extends the correction to those cells that do not have MNNs.
The choice of \code{sigma} determines the extent of smoothing - a value of 0.1 is used by default, corresponding to 10\% of the radius of the space after cosine normalization.

% We would consider 20 cells involved in MNN pairs to be the minimum number required for stable batch correction.
}
\section{Choosing the gene set}{

All genes are used with the default setting of \code{subset.row=NULL}.
Users can set \code{subset.row} to subset the inputs to highly variable genes or marker genes.
This may provide more meaningful identification of MNN pairs by reducing the noise from irrelevant genes.
Note that users should not be too restrictive with subsetting, as high dimensionality is required to satisfy the orthogonality assumption in MNN detection.

If \code{subset.row} is specified and \code{correct.all=TRUE}, corrected values are returned for \emph{all} genes.
This is possible as \code{subset.row} is only used to identify the MNN pairs and other cell-based distance calculations.
Correction vectors between MNN pairs can then be computed in for all genes in the supplied matrices.
Note that setting \code{correct.all=TRUE} will not alter the corrected expression values for the subsetted genes.
}

\section{Expected type of input data}{

The input expression values should generally be log-transformed, e.g., log-counts, see \code{\link[scater]{logNormCounts}} for details.
They should also be normalized within each data set to remove cell-specific biases in capture efficiency and sequencing depth.
By default, a further cosine normalization step is performed on the supplied expression data to eliminate gross scaling differences between data sets.
\itemize{
\item When \code{cos.norm.in=TRUE}, cosine normalization is performed on the matrix of expression values used to compute distances between cells.
This can be turned off when there are no scaling differences between data sets. 
\item When \code{cos.norm.out=TRUE}, cosine normalization is performed on the matrix of values used to calculate correction vectors (and on which those vectors are applied).
This can be turned off to obtain corrected values on the log-scale, similar to the input data.
}
The cosine normalization is achieved using the \code{\link{cosineNorm}} function.
}

\section{Further options}{

The function depends on a shared biological manifold, i.e., one or more cell types/states being present in multiple batches.
If this is not true, MNNs may be incorrectly identified, resulting in over-correction and removal of interesting biology.
Some protection can be provided by removing components of the correction vectors that are parallel to the biological subspaces in each batch.
The biological subspace in each batch is identified with a SVD on the expression matrix to obtain \code{svd.dim} dimensions.
(By default, this option is turned off by setting \code{svd.dim=0}.)

If \code{var.adj=TRUE}, the function will adjust the correction vector to equalize the variances of the two data sets along the batch effect vector.
In particular, it avoids \dQuote{kissing} effects whereby MNN pairs are identified between the surfaces of point clouds from different batches.
Naive correction would then bring only the surfaces into contact, rather than fully merging the clouds together.
The adjustment ensures that the cells from the two batches are properly intermingled after correction.
This is done by identifying each cell's position on the correction vector, identifying corresponding quantiles between batches, 
and scaling the correction vector to ensure that the quantiles are matched after correction.

See \code{?"\link{batchelor-restrict}"} for a description of the \code{restrict} argument.
Specifically, \code{mnnCorrect} will only use the restricted subset of cells in each batch to identify MNN pairs (and to perform variance adjustment, if \code{var.adj=TRUE}), and then apply the correction to all cells in each batch.
}

\section{Merge diagnostics}{

Each merge step combines two mutually exclusive sets of cells, a \dQuote{left} set and \dQuote{right} set.
The metadata thus contains the following fields:
\itemize{
\item \code{left}, a \linkS4class{List} of integer or character vectors.
Each vector specifies the batches in the left set at a given merge step. 
\item \code{right}, a similar List of integer or character vectors.
Each vector specifies the batches in the right set at a given merge step. 
\item \code{pairs}, a List of DataFrames specifying which pairs of cells were identified as MNNs at each step.
In each DataFrame, each row corresponds to a single MNN pair and specifies the
paired cells that were in the left and right sets, respectively.
Note that the indices refer to those paired cells in the \emph{output} ordering of cells,
i.e., users can identify the paired cells at each step by column-indexing the output of the \code{mnnCorrect} function.
}
}

\section{Specifying the number of neighbors}{

The threshold to define nearest neighbors is defined by \code{k}, which is passed to \code{\link{findMutualNN}} to identify MNN pairs.
The size of \code{k} can be roughly interpreted as the anticipated minimum size of a shared subpopulation in each batch.
If a batch has fewer than \code{k} cells of a shared subpopulation, there is an increased risk that its counterparts in other batches will form incorrect MNN pairs.

From the perspective of the algorithm, larger values allow for more MNN pairs to be obtained, which improves the stability of the correction vectors.
Larger values also increase robustness against non-orthogonality, by ignoring a certain level of biological variation when identifying pairs.
This can be used to avoid the kissing problem where MNN pairs are only detected on the \dQuote{surface} of the distribution.
However, values of \code{k} should not be too large, as this would result in MNN pairs being inappropriately identified between biologically distinct populations.

In practice, increasing \code{k} will generally result in more aggressive merging as the algorithm is more generous in matching subpopulations across batches.
We suggest starting with the default \code{k} and increasing it if one is confident that the same cell types are not adequately merged across batches.
This is better than starting with a large \code{k} as incorrect merging is much harder to diagnose than insufficient merging.

An additional consideration is that the effect of any given \code{k} will vary with the number of cells in each batch.
With more cells, a larger \code{k} may be preferable to achieve better merging in the presence of non-orthogonality.
We can achieve this by setting \code{prop.k}, e.g., \code{prop.k=0.05} will set \code{k} to 5\% of the number of cells in each batch.
This allows the choice of \code{k} to adapt to the size of each batch at each merge step and handles asymmetry in batch sizes (via the \code{k1} and \code{k2} arguments in \code{\link{findMutualNN}}).
}

\section{Controlling the merge order}{

By default, batches are merged in the user-supplied order, 
i.e., the first batch is merged with the second batch, 
the third batch is merged with the combined first-second batch,
the fourth batch is merged with the combined first-second-third batch and so on.
We refer to this approach as a progressive merge.

If \code{merge.order} is an integer vector, it is treated as an ordering permutation with which to perform a progressive merge.
For example, if \code{merge.order=c(4,1,3,2)}, batches 4 and 1 in \code{...} are merged first;
batch 3 is merged with the combined 4+1 batch; 
and then batch 2 is merged with the combined 4+1+3 batch.
This is often more convenient than changing the order manually in \code{...}, 
which would alter the order of batches in the output \code{corrected} matrix.

If \code{merge.order} is a character vector, it is treated as an ordering permutation for named batches.

If \code{merge.order} is a nested list, it is treated as a tree that specifies a hierarchical merge.
Each element of the list should either be a string or integer scalar, corresponding to a leaf node that specifies a batch;
or another list, corresponding to an internal node that should contain at least two children;
or an integer or character vector of length 2 or more, again corresponding to an internal node.
\itemize{
\item For example, \code{list(list(1,2), list(3,4))} indicates that batch 1 should be merged with batch 2;
batch 3 should be merged with batch 4; and that, finally, the combined batches 1+2 and 3+4 should be merged.
\item More than two children per node are supported and will result in a progressive merge within that node.
For example, \code{list(list(1,2,3), list(4,5,6))} will merge batch 1 with 2, then 1+2 with 3;
batch 4 with 5, and then 4+5 with 6; and finally, 1+2+3 with 4+5+6.
\item The same approach can be used for integer or character vectors, e.g., \code{list(1:3, 4:6)} has the same effect as above.
}
Note that, while batches can be specified by name (character) or index (integer), users cannot use both in the same tree.

The merge order may occasionally be important as it determines the number of MNN pairs available at each merge step.
MNN pairs results in greater stability of the batch vectors and increased likelihood of identifying shared subpopulations,
which are important to the precision and accuracy of the MNN-based correction, respectively.
\itemize{
\item  In a progressive merge, the reference increases in size at each step,
ensuring that more cells are available to identify MNN pairs in later merges.
We suggest setting the largest, most heterogeneous batch as the first reference,
which favors detection of sufficient MNN pairs between the first and other batches.
Conversely, if two small batches without shared populations are supplied first, 
the wrong MNN pairs will be detected and the result of the merge will be incorrect.
\item A merge tree is useful for merging together batches that are known to be more closely related (e.g., replicates)
before attempting difficult merges involving more dissimilar batches.
The idea is to increase the number of cells and thus MNN pairs prior to merging batches with few shared subpopulations.
By comparison, performing the more difficult merges first is more likely to introduce errors whereby distinct subpopulations are incorrectly placed together, which is propagated to later steps as the initial merge is used as a reference for subsequent merges.
\item If \code{auto.merge=TRUE}, merge steps are chosen to maximize the number of MNN pairs at each step.
The aim is to improve the stability of the correction by first merging more similar batches with more MNN pairs.
This can be somewhat time-consuming as MNN pairs need to be iteratively recomputed for all possible batch pairings.
}

The order of cells in the output is \emph{never} affected by the setting of \code{merge.order}.
It depends only on the order of objects in \code{...} and the order of cells within each object.
}

\examples{
B1 <- matrix(rnorm(10000), ncol=50) # Batch 1 
B2 <- matrix(rnorm(10000), ncol=50) # Batch 2
out <- mnnCorrect(B1, B2) # corrected values

}
\references{
Haghverdi L, Lun ATL, Morgan MD, Marioni JC (2018).
Batch effects in single-cell RNA-sequencing data are corrected by matching mutual nearest neighbors.
\emph{Nat. Biotechnol.} 36(5):421
}
\seealso{
\code{\link{fastMNN}} for a faster equivalent.
}
\author{
Laleh Haghverdi,
with modifications by Aaron Lun
}
