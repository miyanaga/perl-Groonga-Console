#ifdef __cplusplus
extern "C" {
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#ifdef __cplusplus
}
#endif

#include <groonga/groonga.h>
#include <string>
#include <list>

using namespace std;

typedef list<string> strings;

class Groonga {
    private:
        static bool initialized;

        int context_flags;
        grn_ctx context;
        grn_obj *database;

    public:
        static string last_error;
        static void set_last_error(string);

        Groonga( string path, int context_flags = 0 /*GRN_CTX_BATCH_MODE*/ );
        ~Groonga();

        strings errors;
        void add_error(string);
        void add_context_error();
        void clear_errors();

        bool is_connected();
        void console( strings &, strings & );
};

bool Groonga::initialized = FALSE;
string Groonga::last_error;

Groonga::Groonga( string path, int _context_flags ) {
    context_flags = _context_flags;
    database = NULL;

    // Initialize groonga if not.
    if ( !Groonga::initialized ) {
        grn_init();
        Groonga::initialized = TRUE;
    }

    // Initialize context.
    grn_ctx_init( &context, context_flags );
    if ( path.length() > 0 ) {
        // Open or create database.
        GRN_DB_OPEN_OR_CREATE( &context, path.c_str(), NULL, database );
    } else {
        // On memory or temporary?
        database = grn_db_create( &context, NULL, NULL );
    }

    if ( context.rc != GRN_SUCCESS ) {
        // Failed to prepare database.
        add_context_error();
        database = NULL;
    }
}

Groonga::~Groonga() {
    // Free context.
    grn_ctx_fin(&context);
}

void Groonga::add_error(string error) {
    // Add error to stack and set as the last error.
    Groonga::last_error = error;
    errors.push_back(Groonga::last_error);
}

void Groonga::add_context_error() {
    // Add error from context to stack and set as the last error.
    Groonga::last_error = context.errbuf;
    errors.push_back(Groonga::last_error);
}

void Groonga::clear_errors() {
    // Clear errors stack.
    errors.clear();
}

bool Groonga::is_connected() {
    // Check if database opened.
    return database != NULL? TRUE: FALSE;
}

void Groonga::console( strings &input, strings &output ) {
    int rc;

    if ( !database ) {
        add_error( "Database not opened." );
        return;
    }

    for ( strings::iterator it = input.begin(), end = input.end(); it != end; it++ ) {
        // Split to lines because groonga accepts only a line for each time.
        string &str = *it;
        str += "\n";

        // Append line break.
        string::size_type start = 0;
        strings lines;
        for( string::size_type pos = str.find("\n"); pos != string::npos; pos = str.find("\n", pos + 1) ) {
            if ( pos == string::npos ) {
                // Last one.
                lines.push_back(str.substr(start));
                break;
            } else {
                // Continue to split.
                lines.push_back(str.substr(start, pos - start));
                start = pos + 1;
            }
        }

        // Send to groonga.
        for ( strings::iterator it = lines.begin(), end = lines.end(); it != end; it++ ) {
            // Skip empty line.
            string &line = *it;
            if ( line.length() < 1 ) continue;

            rc = grn_ctx_send( &context, line.c_str(), line.length(), context_flags );

            // Handle errors.
            if ( rc < 0 ) {
                string message = "Failure to send: " + line;
                add_error(message);
                return;
            }
            if ( context.rc != GRN_SUCCESS ) {
                add_context_error();
                return;
            }

            // Try to receive result.
            char *res;
            unsigned int len;
            int flags;
            grn_ctx_recv( &context, &res, &len, &flags );
            if ( context.rc == GRN_SUCCESS && len > 0 ) {
                output.push_back(string(res, len));
            } else if ( context.rc != GRN_SUCCESS ) {
                add_context_error();
            }
        }
    }
}

MODULE = Groonga::Console		PACKAGE = Groonga::Console

static SV *
Groonga::last_error()
    CODE:
        RETVAL = newSVpv( Groonga::last_error.c_str(), Groonga::last_error.length() );
    OUTPUT:
        RETVAL

PROTOTYPES: ENABLE

Groonga *
Groonga::new( path = NULL )
    char *path
    CODE:
        RETVAL = new Groonga( path != NULL? string(path): "" );
        if ( !RETVAL->is_connected() ) {
            delete RETVAL;
            XSRETURN_UNDEF;
        }
    OUTPUT:
        RETVAL

bool
Groonga::is_connected()

void
Groonga::add_error( error )
    char *error
    CODE:
        THIS->errors.push_back(string(error));

void
Groonga::errors()
    PPCODE:
        strings &errs = THIS->errors;
        for( strings::iterator it = errs.begin(), end = errs.end(); it != end; it++ ) {
            string &err = *it;
            XPUSHs(sv_2mortal(newSVpv( err.c_str(), err.length() )));
        }

void
Groonga::clear_errors()
    CODE:
        THIS->errors.clear();

void
Groonga::console(...)
    PPCODE:
        strings input, output;
        for ( int i = 1; i < items; i++ ) {
            input.push_back((char*)SvPV_nolen(ST(i)));
        }
        THIS->console( input, output );
        for ( strings::iterator it = output.begin(), end = output.end(); it != end; it++ ) {
            string &result = *it;
            XPUSHs(sv_2mortal(newSVpv( result.c_str(), result.length() )));
        }
