pic = 1;
mov = 2;

ML_Benchmark = true;
ML_BenchmarkSample = zeros(35000,1);
ML_BenchmarkFrame = zeros(500,1);
varargout{1} = cell(2,2);

for m=1:2
    dashboard(1,sprintf('Testing the screen flipping latency... (Pass %d/2)',m));
    
    ML_BenchmarkSampleCount = 1;
    ML_BenchmarkFrameCount = 1;
    time_of_flip = toggleobject(pic,'status','on');
    idle(1000);
    toggleobject(pic,'status','off');
    ML_BenchmarkSample(1,1) = time_of_flip;
    ML_BenchmarkFrame(1,2) = time_of_flip;
    varargout{1}{1,m} = { ML_BenchmarkSample(1:ML_BenchmarkSampleCount,1), ML_BenchmarkFrame(1:ML_BenchmarkFrameCount,2) };

    ML_BenchmarkSampleCount = 1;
    ML_BenchmarkFrameCount = 1;
    time_of_flip = toggleobject(mov,'status','on');
    idle(1000);
    toggleobject(mov,'status','off');
    ML_BenchmarkSample(1,1) = time_of_flip;
    ML_BenchmarkFrame(1,2) = time_of_flip;
    varargout{1}{2,m} = { ML_BenchmarkSample(1:ML_BenchmarkSampleCount,1), ML_BenchmarkFrame(1:ML_BenchmarkFrameCount,2) };
    rewind_movie(mov);
end
