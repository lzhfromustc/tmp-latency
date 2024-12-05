#!/usr/bin/perl

# Visits every directory, calls make, and then executes the benchmark
# (Designed for making sure every kernel compiles/runs after modifications)
#
# Written by Tomofumi Yuki, 01/15 2015
#

my $TARGET_DIR = ".";

if ($#ARGV != 0 && $#ARGV != 1) {
   printf("usage perl run-all.pl target-dir [output-file]\n");
   exit(1);
}



if ($#ARGV >= 0) {
   $TARGET_DIR = $ARGV[0];
}

my $OUTFILE = "";
if ($#ARGV == 1) {
   $OUTFILE = $ARGV[1];
}


my @categories = ('linear-algebra/blas',
                  'linear-algebra/kernels',
                  'linear-algebra/solvers',
                  'datamining',
                  'stencils',
                  'medley');


foreach $cat (@categories) {
   my $target = $TARGET_DIR.'/'.$cat;
   opendir DIR, $target or die "directory $target not found.\n";
   while (my $dir = readdir DIR) {
        next if ($dir=~'^\..*');
        next if (!(-d $target.'/'.$dir));

        my $kernel = $dir;
        my $targetDir = $target.'/'.$dir;
        my $command = "cd $targetDir; make clean; make; sudo perf stat -e task-clock,cycles,instructions,mem_load_retired.l1_hit,mem_load_retired.l1_miss,mem_load_retired.l2_hit,mem_load_retired.l2_miss,mem_load_retired.l3_hit,mem_load_retired.l3_miss ./$kernel";
	$command .= " 2>> $OUTFILE" if ($OUTFILE ne '');
        print($command."\n");
        system($command);
   }

   closedir DIR;
}

#  2000  gcc -I utilities -I linear-algebra/kernels/bicg utilities/polybench.c linear-algebra/kernels/bicg/bicg.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o bicg-ex
#  2001  gcc -I utilities -I linear-algebra/kernels/bicg utilities/polybench.c linear-algebra/kernels/bicg/bicg.c -DPOLYBENCH_TIME -DLARGE_DATASET -o bicg-l
#  2002  gcc -I utilities -I linear-algebra/kernels/doitgen utilities/polybench.c linear-algebra/kernels/doitgen/doitgen.c -DPOLYBENCH_TIME -DLARGE_DATASET -o doitgen-l
#  2003  gcc -I utilities -I linear-algebra/kernels/mvt utilities/polybench.c linear-algebra/kernels/mvt/mvt.c -DPOLYBENCH_TIME -DLARGE_DATASET -o mvt-l
#  2004  gcc -I utilities -I linear-algebra/kernels/doitgen utilities/polybench.c linear-algebra/kernels/doitgen/doitgen.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o doitgen-ex
#  2005  gcc -I utilities -I linear-algebra/kernels/mvt utilities/polybench.c linear-algebra/kernels/mvt/mvt.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o mvt-ex
#  2006  gcc -I utilities -I linear-algebra/blas/gemm utilities/polybench.c linear-algebra/blas/gemm/gemm.c -DPOLYBENCH_TIME -DLARGE_DATASET -o gemm-l
#  2007  gcc -I utilities -I linear-algebra/blas/gemver/ utilities/polybench.c linear-algebra/blas/gemver/gemver.c -DPOLYBENCH_TIME -DLARGE_DATASET -o gemver-l
#  2008  gcc -I utilities -I linear-algebra/blas/gesummv/ utilities/polybench.c linear-algebra/blas/gesummv/gesummv.c -DPOLYBENCH_TIME -DLARGE_DATASET -o gesummv-l
#  2009  gcc -I utilities -I linear-algebra/blas/symm utilities/polybench.c linear-algebra/blas/symm/symm.c -DPOLYBENCH_TIME -DLARGE_DATASET -o symm-l
#  2010  gcc -I utilities -I linear-algebra/blas/symm utilities/polybench.c linear-algebra/blas/symm/symm.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o symm-ex
#  2011  gcc -I utilities -I linear-algebra/blas/syr2k utilities/polybench.c linear-algebra/blas/syr2k/syr2k.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o syr2k
#  2012  mv syr2k syr2k-ex
#  2013  gcc -I utilities -I linear-algebra/blas/syrk utilities/polybench.c linear-algebra/blas/syrk/syrk.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o syrk-ex
#  2014  gcc -I utilities -I linear-algebra/blas/trmm utilities/polybench.c linear-algebra/blas/trmm/trmm.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o trmm-ex
#  2015* gcc -I utilities -I linear-algebra/blas/syr2k utilities/polybench.c linear-algebra/blas/syr2k/syr2k.c -DPOLYBENCH_TIME -DLARGE_DATASET -o 
#  2016  gcc -I utilities -I linear-algebra/solvers/cholesky utilities/polybench.c linear-algebra/solvers/cholesky/cholesky.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o cholesky-ex
#  2017  gcc -I utilities -I linear-algebra/solvers/cholesky utilities/polybench.c linear-algebra/solvers/cholesky/cholesky.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o cholesky-ex
#  2018  gcc -I utilities -I linear-algebra/solvers/durbin utilities/polybench.c linear-algebra/solvers/durbin/durbin.c -DPOLYBENCH_TIME -DLARGE_DATASET -lm -o durbin-l
#  2019  gcc -I utilities -I linear-algebra/solvers/gramschmidt utilities/polybench.c linear-algebra/solvers/gramschmidt/gramschmidt.c -DPOLYBENCH_TIME -DLARGE_DATASET -lm -o gramschmidt-l
#  2020  gcc -I utilities -I linear-algebra/solvers/lu utilities/polybench.c linear-algebra/solvers/lu/lu.c -DPOLYBENCH_TIME -DLARGE_DATASET -lm -o lu-l
#  2021  gcc -I utilities -I linear-algebra/solvers/ludcmp utilities/polybench.c linear-algebra/solvers/ludcmp/ludcmp.c -DPOLYBENCH_TIME -DLARGE_DATASET -lm -o ludcmp-l
#  2022  gcc -I utilities -I linear-algebra/solvers/trisolv utilities/polybench.c linear-algebra/solvers/trisolv/trisolv.c -DPOLYBENCH_TIME -DLARGE_DATASET -lm -o trisolv-l
#  2023  cd utilities/
#  2024  cp run-all.pl run-all-perf.pl 
#  2025  cd ../medley/deriche/
#  2026  make
#  2027  cd ../..
#  2028  gcc -I utilities -I linear-algebra/solvers/gramschmidt utilities/polybench.c linear-algebra/solvers/gramschmidt/gramschmidt.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o gramschmidt-ex
#  2029  cd utilities/
#  2030  pwd
#  2031  cd ..
#  2032  gcc -I utilities -I stencils/adi utilities/polybench.c stencils/adi/adi.c -DPOLYBENCH_TIME -DLARGE_DATASET -o adi-l
#  2033  gcc -I utilities -I stencils/fdtd-2d/ utilities/polybench.c stencils/fdtd-2d/fdtd-2d.c -DPOLYBENCH_TIME -DLARGE_DATASET -o fdtd-2d
#  2034  mv fdtd-2d fdtd-2d-l
#  2035  gcc -I utilities -I stencils/heat-3d utilities/polybench.c stencils/heat-3d/heat-3d.c -DPOLYBENCH_TIME -DLARGE_DATASET -o head-3d-l
#  2036  gcc -I utilities -I stencils/seidel-2d utilities/polybench.c stencils/seidel-2d/seidel-2d.c -DPOLYBENCH_TIME -DLARGE_DATASET -o seidel-2d-l
#  2037  gcc -I utilities -I medley/deriche utilities/polybench.c medley/deriche/deriche.c -DPOLYBENCH_TIME -DLARGE_DATASET -o deriche-l
#  2038  gcc -I utilities -I medley/deriche utilities/polybench.c medley/deriche/deriche.c -DPOLYBENCH_TIME -DLARGE_DATASET -ld -o deriche-l
#  2039  gcc -I utilities -I medley/deriche utilities/polybench.c medley/deriche/deriche.c -DPOLYBENCH_TIME -DLARGE_DATASET -lm -o deriche-l
#  2040  gcc -I utilities -I stencils/fdtd-2d/ utilities/polybench.c stencils/fdtd-2d/fdtd-2d.c -DPOLYBENCH_TIME -DLARGE_DATASET -lm -o fdtd-2d
#  2041  gcc -I utilities -I medley/floyd-warshall utilities/polybench.c medley/floyd-warshall/floyd-warshall.c -DPOLYBENCH_TIME -DLARGE_DATASET -lm -o floyd
#  2042  mv floyd floyd-l
#  2043  gcc -I utilities -I medley/nussinov utilities/polybench.c medley/nussinov/nussinov.c -DPOLYBENCH_TIME -DLARGE_DATASET -lm -o nussinov-l
#  2044  gcc -I utilities -I datamining/correlation utilities/polybench.c datamining/correlation/correlation.c -DPOLYBENCH_TIME -DLARGE_DATASET -lm -o correlation-l
#  2045* gcc -I utilities -I datamining/covariance utilities/polybench.c datamining/covariance/covariance.c -DPOLYBENCH_TIME -DLARGE_DATASET -lm -o covariance-e
#  2046  gcc -I utilities -I datamining/covariance utilities/polybench.c datamining/covariance/covariance.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o covariance-ex
#  2047  gcc -I utilities -I datamining/correlation utilities/polybench.c datamining/correlation/correlation.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o correlation-ex
#  2048  gcc -I utilities -I medley/nussinov utilities/polybench.c medley/nussinov/nussinov.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o nussinov-ex
#  2049  gcc -I utilities -I linear-algebra/solvers/ludcmp utilities/polybench.c linear-algebra/solvers/ludcmp/ludcmp.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o ludcmp-ex
#  2050  gcc -I utilities -I linear-algebra/solvers/lu utilities/polybench.c linear-algebra/solvers/lu/lu.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o lu-ex