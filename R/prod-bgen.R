################################################################################

#' BGEN matrix product
#'
#' Compute a matrix product between BGEN files and a matrix. This removes the
#' need to read an intermediate FBM object with [snp_readBGEN()] to compute the
#' product. Moreover, when using dosages, they are not rounded to two decimal
#' places anymore.
#'
#' @seealso [snp_readBGEN()]
#'
#' @inheritParams snp_readBGEN
#' @param beta A matrix (or a vector), with rows corresponding to `list_snp_id`.
#'
#' @return The product `bgen_data[ind_row, 'list_snp_id'] %*% beta`.
#'
#' @export
snp_prodBGEN <- function(bgenfiles, beta, list_snp_id,
                         ind_row = NULL,
                         bgi_dir = dirname(bgenfiles),
                         read_as = c("dosage", "random"),
                         ncores = 1) {

  # this function uses utility functions from 'read-bgen.R'

  dosage <- identical(match.arg(read_as), "dosage")

  if (is_vec <- is.null(dim(beta)))
    beta <- as.matrix(beta)

  # Check extension of files
  bgenfiles <- path.expand(bgenfiles)
  sapply(bgenfiles, assert_ext, ext = "bgen")
  # Check if all files exist
  bgifiles <- file.path(bgi_dir, paste0(basename(bgenfiles), ".bgi"))
  sapply(c(bgenfiles, bgifiles), assert_exist)

  # Check list_snp_id
  assert_class(list_snp_id, "list")
  sapply(list_snp_id, assert_nona)
  assert_lengths(list_snp_id, bgenfiles)
  sizes <- lengths(list_snp_id)

  # Check format of BGEN files + check samples
  all_N <- sapply(bgenfiles, check_bgen_format)
  N <- all_N[1]
  bigassertr::assert_all(all_N, N)
  if (is.null(ind_row)) ind_row <- seq_len(N)
  assert_nona(ind_row)
  stopifnot(all(ind_row >= 1 & ind_row <= N))

  # Compute the product from BGEN files
  res <- Reduce('+', lapply(seq_along(bgenfiles), function(ic) {

    snp_id <- format_snp_id(list_snp_id[[ic]])
    start_pos_in_file <- snp_readBGI(bgifiles[ic], snp_id)$file_start_position

    ind.col <- sum(sizes[seq_len(ic - 1)]) + seq_len(sizes[ic])
    res_chr <- prod_bgen(
      filename   = bgenfiles[ic],
      offsets    = as.double(start_pos_in_file),
      beta_trans = t(beta[ind.col, , drop = FALSE]),
      ind_row    = ind_row - 1L,
      decode     = 510:0 / 255,
      dosage     = dosage,
      N          = N,
      ncores     = ncores
    )
    base::rowSums(res_chr, dims = 2)
  }))

  `if`(is_vec, drop(res), res)
}

################################################################################