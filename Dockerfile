FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    texlive-latex-base \
    texlive-latex-recommended \
    texlive-latex-extra \
    texlive-science \
    texlive-pictures \
    texlive-fonts-recommended \
    texlive-fonts-extra \
    texlive-plain-generic \
    latexmk \
    gnuplot-nox \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

CMD ["latexmk", "-pdf", "-shell-escape"]