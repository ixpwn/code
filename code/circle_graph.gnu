set terminal postscript eps color font "Times, 22"
set output "circle_graph.ps"
set title "Scatter plot of ASN information"
set xlabel "Triangles an ASN is in"
set ylabel "Number of Neighbors"
#set logscale x
#set logscale y
plot "circle_graph.data" using 1:2:3 notitle with circles fs noborder

