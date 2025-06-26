"""
Main application module for Parallel Matrix Formatter.

This module demonstrates the centralized configuration pattern where all
components receive configuration through the Config object instead of
accessing environment variables directly.
"""

import logging
import sys
from typing import List
from .config_loader import get_config, Config
from .matrix_processor import Matrix, create_formatter
from .cache_manager import create_cache_manager


class Application:
    """
    Main application class that coordinates all components.
    
    This class demonstrates how to structure an application using the
    centralized configuration pattern. All components receive the same
    configuration object, ensuring consistency across the application.
    """
    
    def __init__(self, config_file: str = None):
        """
        Initialize the application with centralized configuration.
        
        Args:
            config_file: Optional path to configuration file
        """
        # Load centralized configuration once for the entire application
        self._config = get_config(config_file)
        
        # Set up application-level logging
        self._logger = self._setup_logging()
        
        # Initialize components with the shared configuration
        self._formatter = create_formatter()
        self._cache_manager = create_cache_manager()
        
        self._logger.info("Application initialized with centralized configuration")
    
    def _setup_logging(self) -> logging.Logger:
        """
        Set up application-level logging using configuration.
        
        Returns:
            Configured logger instance
        """
        # Configure root logger based on configuration
        logging.basicConfig(
            level=getattr(logging, self._config.logging.level.upper()),
            format=self._config.logging.format
        )
        
        logger = logging.getLogger(__name__)
        
        if self._config.debug.enabled:
            logger.info("Debug mode enabled")
        
        return logger
    
    def run_example(self) -> None:
        """
        Run an example matrix processing workflow.
        
        This method demonstrates how the application uses the centralized
        configuration throughout its execution.
        """
        self._logger.info("Starting matrix processing example")
        
        # Create example matrices
        matrices = self._create_example_matrices()
        
        # Process matrices using configured formatter
        try:
            results = self._formatter.process_matrices(matrices)
            
            # Display results according to configuration
            self._display_results(results)
            
            self._logger.info("Matrix processing completed successfully")
            
        except Exception as e:
            self._logger.error(f"Matrix processing failed: {e}")
            if self._config.debug.enabled:
                import traceback
                self._logger.debug(traceback.format_exc())
    
    def _create_example_matrices(self) -> List[Matrix]:
        """
        Create example matrices for demonstration.
        
        Returns:
            List of example Matrix objects
        """
        matrices = [
            Matrix(
                data=[[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]],
                rows=2,
                cols=3
            ),
            Matrix(
                data=[[7.123, 8.456], [9.789, 10.012]],
                rows=2,
                cols=2
            ),
            Matrix(
                data=[[11.1], [22.2], [33.3]],
                rows=3,
                cols=1
            )
        ]
        
        self._logger.info(f"Created {len(matrices)} example matrices")
        return matrices
    
    def _display_results(self, results: List[str]) -> None:
        """
        Display processing results according to configuration.
        
        Args:
            results: List of formatted matrix strings
        """
        output_format = self._config.output.format
        
        self._logger.info(f"Displaying results in {output_format} format:")
        
        for i, result in enumerate(results, 1):
            print(f"\n--- Matrix {i} ({output_format}) ---")
            print(result)
    
    def get_config_summary(self) -> str:
        """
        Get a summary of the current configuration.
        
        Returns:
            String representation of the configuration
        """
        summary = f"""
Configuration Summary:
=====================
Logging Level: {self._config.logging.level}
Parallel Workers: {self._config.parallel.workers}
Max Matrix Size: {self._config.matrix.max_size}
Output Format: {self._config.output.format}
Cache Enabled: {self._config.cache.enabled}
Cache TTL: {self._config.cache.ttl}s
Debug Mode: {self._config.debug.enabled}
        """.strip()
        
        return summary


def main():
    """
    Main entry point for the application.
    
    This function demonstrates how to initialize and run an application
    using the centralized configuration pattern.
    """
    try:
        # Create application instance (loads configuration centrally)
        app = Application()
        
        # Display configuration summary
        print(app.get_config_summary())
        print("\n" + "="*50 + "\n")
        
        # Run the example
        app.run_example()
        
    except Exception as e:
        print(f"Application failed to start: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()