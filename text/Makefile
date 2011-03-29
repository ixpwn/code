ROOTNAME =resilience
;SUBMITNAME =telemed_system_submit
PDFFILE = $(ROOTNAME).pdf
PSFILE = $(ROOTNAME).ps
DVIFILE = $(ROOTNAME).dvi
TEXFILE = $(ROOTNAME).tex
ID=131

#EXPANDED_TEXFILE=$(SUBMITNAME)_full.tex


WEBLOCATION = 




all: standard

standard: 
	make bbl
	make dvi
	make ps
	make pdf

dvi:
	latex $(ROOTNAME)
	latex $(ROOTNAME)
	latex $(ROOTNAME)

ps:
	dvips -P cmz -t letter  -o $(PSFILE) $(DVIFILE)

pdf:
	ps2pdf -dEmbedAllFonts=true -dCompatibilityLevel=1.4 $(PSFILE) $(PDFFILE)

pdflatex: clean
	pdflatex $(ROOTNAME)
	pdflatex $(ROOTNAME)
	pdflatex $(ROOTNAME)
	
bbl:
	latex $(ROOTNAME)
	bibtex $(ROOTNAME) 

submit:
	make all
	#scp $(ROOTNAME).pdf $(WEBLOCATION)
	#cp $(ROOTNAME).pdf $(SUBMITNAME).pdf
	perl ./latex_makeone.pl $(TEXFILE) $(SUBMITNAME).tex 
	@echo  "expanded tex file: $(SUBMITNAME).tex"
	@echo  "pdf submit file: $(SUBMITNAME).pdf"


clean:
	rm -f *.dvi *.ps *.pdf *.aux *.bbl *.blg *.ent *.log *.out $(DRAFT_SETTINGS)



publish:
	scp $(ROOTNAME).pdf shirin:public_html/Stuff/docs/



html: $(ROOTNAME).tex
	cat $(ROOTNAME).tex| tth -w4 -r -L $(ROOTNAME) -e2 > $(ROOTNAME).html 

nsdi: 
	mkdir -p $(ROOTNAME)_$(ID)
	sed -i s/0.88// $(ROOTNAME).html
	grep -A 4000 Abstract $(ROOTNAME).html > /tmp/body.html
	cat nsdi_tex/title.html /tmp/body.html > $(ROOTNAME)_$(ID)/$(ROOTNAME)_submit.html
	tar -cf - figures/*.png | tar -C $(ROOTNAME)_$(ID)/ -xf -
	cp $(ROOTNAME).pdf 	$(ROOTNAME)_$(ID)/$(ROOTNAME)_submit.pdf
	cp $(ROOTNAME).ps   $(ROOTNAME)_$(ID)/$(ROOTNAME)_submit.ps
	tar -zcvf $(ROOTNAME)_$(ID).tar.gz $(ROOTNAME)_$(ID)/
