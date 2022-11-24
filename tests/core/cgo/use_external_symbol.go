package use_external_symbol

/*
void external_symbol();
*/
import "C"

func UseExternalSymbol() {
	C.external_symbol()
}
