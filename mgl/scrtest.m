monitor = GetMonitorPosition;

for m=1:size(monitor,1)
    h = figure;
    text(0,0,sprintf('%d',m));
    set(gca,'XLim',[-1 1], 'YLim',[-1 1]);
    set(h,'position',monitor(m,:));
end
