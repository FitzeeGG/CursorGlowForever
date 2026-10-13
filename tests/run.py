"""Runs every test against the addon in a simulated client.

    python tests/run.py [--debug]
"""
import sys

from harness import Sim
import test_hover
import test_features


def main():
	sim = Sim(debug="--debug" in sys.argv)
	for module in (test_hover, test_features):
		print(module.__doc__.splitlines()[0])
		module.run(sim)
	failed = [label for label, ok in sim.results if not ok]
	print("%d checks, %d failed" % (len(sim.results), len(failed)))
	print("ALL PASSED" if not failed else "FAILURES:\n  " + "\n  ".join(failed))
	sys.exit(1 if failed else 0)


if __name__ == "__main__":
	main()
