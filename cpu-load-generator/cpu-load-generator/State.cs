namespace cpu_load_generator;

public class State
{
    public CancellationTokenSource Cts { get; }
    
    public int Percentage { get; }

    public State(CancellationTokenSource cts, int percentage)
    {
        Cts = cts;
        Percentage = percentage;
    }
}
