package e2e_test

import (
	"context"
	"io"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/wait"
)

func TestShellspecE2EInContainer(t *testing.T) {
	if os.Getenv("MISE_NIX_REQUIRE_DOCKER") != "1" {
		testcontainers.SkipIfProviderIsNotHealthy(t)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Minute)
	defer cancel()

	ctr, err := testcontainers.Run(ctx, "",
		testcontainers.WithDockerfile(testcontainers.FromDockerfile{
			Context:    "..",
			Dockerfile: "Dockerfile",
			Repo:       "mise-nix-e2e",
			Tag:        "test",
		}),
		testcontainers.WithWaitStrategyAndDeadline(90*time.Minute, wait.ForExit().WithExitTimeout(90*time.Minute)),
		testcontainers.WithCmd("/workspace/scripts/run-isolated-e2e.sh"),
	)
	if err != nil {
		t.Fatalf("run isolated e2e container: %v", err)
	}
	defer func() {
		if err := testcontainers.TerminateContainer(ctr); err != nil {
			t.Logf("terminate isolated e2e container: %v", err)
		}
	}()

	output := containerLogs(t, ctx, ctr)
	state, err := ctr.State(ctx)
	if err != nil {
		t.Fatalf("inspect isolated e2e container: %v\n%s", err, output)
	}
	if state.ExitCode != 0 {
		t.Fatalf("isolated e2e failed with exit code %d\n%s", state.ExitCode, output)
	}
	if !strings.Contains(output, "successes") {
		t.Fatalf("isolated e2e output did not look like a completed shellspec/busted run\n%s", output)
	}
}

type logContainer interface {
	Logs(context.Context) (io.ReadCloser, error)
}

func containerLogs(t *testing.T, ctx context.Context, ctr logContainer) string {
	t.Helper()
	logs, err := ctr.Logs(ctx)
	if err != nil {
		t.Fatalf("read container logs: %v", err)
	}
	defer logs.Close()
	data, err := io.ReadAll(logs)
	if err != nil {
		t.Fatalf("read container log stream: %v", err)
	}
	return string(data)
}
